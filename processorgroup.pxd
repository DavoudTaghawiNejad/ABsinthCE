cimport numpy



cdef class ProcessorGroup:
    cdef numpy.ndarray agents
    cdef int num_processes
    cdef int batch
    cdef int i
    cdef void *sender
    cdef void *in_context
    cdef void *out_context
    cdef void *out_socket
    cdef void *ipc_in_context
    cdef int num_agents
    cdef void *device_to_agents
    cdef void *to_the_world
    cdef void  *from_the_world [3]


