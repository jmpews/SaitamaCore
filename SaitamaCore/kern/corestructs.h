#pragma once
#include <stdint.h>

typedef struct _MINI_KERNEL {
	uint64_t core_size;
	void *core_init_address;
} MINI_KERNEL;