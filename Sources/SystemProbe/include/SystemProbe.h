#ifndef SYSTEM_PROBE_H
#define SYSTEM_PROBE_H
#include <stdint.h>

typedef struct {
    int32_t pid, parent_pid;
    char name[256], path[4096];
    uint64_t start_time, cpu_ns, footprint;
    int readable;
} ARMProcess;

typedef struct {
    uint64_t cpu_busy, cpu_total, physical_memory, used_memory, swap_used;
    int cpu_valid, memory_valid, swap_valid;
} ARMSystem;

// Caller frees the returned array with arm_free_processes.
int arm_processes(ARMProcess **output);
void arm_free_processes(ARMProcess *processes);
ARMSystem arm_system(void);
#endif
