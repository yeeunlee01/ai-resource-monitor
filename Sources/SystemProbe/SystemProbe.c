#include "SystemProbe.h"
#include <libproc.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>

int arm_processes(ARMProcess **output) {
    *output = NULL;
    int capacity = proc_listallpids(NULL, 0) + 256;
    if (capacity <= 256) return -1;
    pid_t *pids = calloc(capacity, sizeof(pid_t));
    if (!pids) return -1;
    int count = proc_listallpids(pids, capacity * sizeof(pid_t));
    if (count < 0) { free(pids); return -1; }
    if (count > capacity) count = capacity;
    ARMProcess *rows = calloc(count, sizeof(ARMProcess));
    if (!rows) { free(pids); return -1; }
    int used = 0;
    mach_timebase_info_data_t timebase = {0};
    mach_timebase_info(&timebase);
    for (int i = 0; i < count; i++) {
        if (pids[i] <= 0) continue;
        ARMProcess row = {0};
        row.pid = pids[i];
        struct proc_bsdinfo bsd = {0};
        if (proc_pidinfo(pids[i], PROC_PIDTBSDINFO, 0, &bsd, sizeof(bsd)) == sizeof(bsd)) {
            row.parent_pid = bsd.pbi_ppid;
        }
        proc_name(pids[i], row.name, sizeof(row.name));
        proc_pidpath(pids[i], row.path, sizeof(row.path));
        struct rusage_info_v2 usage = {0};
        if (proc_pid_rusage(pids[i], RUSAGE_INFO_V2, (rusage_info_t *)&usage) == 0) {
            row.readable = 1;
            row.start_time = usage.ri_proc_start_abstime;
            // rusage_info CPU counters are Mach absolute ticks, not nanoseconds.
            // The ratio is not 1:1 on Apple Silicon. Widen before multiplying.
            __uint128_t ticks = (__uint128_t)usage.ri_user_time + usage.ri_system_time;
            row.cpu_ns = (uint64_t)(ticks * timebase.numer / timebase.denom);
            row.footprint = usage.ri_phys_footprint;
        }
        rows[used++] = row;
    }
    free(pids);
    *output = rows;
    return used;
}

void arm_free_processes(ARMProcess *processes) { free(processes); }

ARMSystem arm_system(void) {
    ARMSystem result = {0};
    mach_port_t host = mach_host_self();
    host_cpu_load_info_data_t cpu = {0};
    mach_msg_type_number_t cpuCount = HOST_CPU_LOAD_INFO_COUNT;
    if (host_statistics(host, HOST_CPU_LOAD_INFO, (host_info_t)&cpu, &cpuCount) == KERN_SUCCESS) {
        result.cpu_busy = (uint64_t)cpu.cpu_ticks[CPU_STATE_USER] + cpu.cpu_ticks[CPU_STATE_SYSTEM] + cpu.cpu_ticks[CPU_STATE_NICE];
        result.cpu_total = result.cpu_busy + cpu.cpu_ticks[CPU_STATE_IDLE];
        result.cpu_valid = 1;
    }
    size_t size = sizeof(result.physical_memory);
    int physical_ok = sysctlbyname("hw.memsize", &result.physical_memory, &size, NULL, 0) == 0;
    vm_statistics64_data_t vm = {0};
    mach_msg_type_number_t vmCount = HOST_VM_INFO64_COUNT;
    vm_size_t pageSize = 0;
    host_page_size(host, &pageSize);
    if (physical_ok && host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vm, &vmCount) == KERN_SUCCESS) {
        // Estimate non-cache memory, counting compressed pages at their physical size.
        uint64_t allocated = (uint64_t)vm.active_count + vm.inactive_count + vm.wire_count + vm.compressor_page_count;
        uint64_t reusable = (uint64_t)vm.purgeable_count + vm.external_page_count;
        result.used_memory = (allocated > reusable ? allocated - reusable : 0) * pageSize;
        if (result.used_memory > result.physical_memory) result.used_memory = result.physical_memory;
        result.memory_valid = 1;
    }
    struct xsw_usage swap = {0};
    size = sizeof(swap);
    if (sysctlbyname("vm.swapusage", &swap, &size, NULL, 0) == 0) {
        result.swap_used = swap.xsu_used;
        result.swap_valid = 1;
    }
    mach_port_deallocate(mach_task_self(), host);
    return result;
}
