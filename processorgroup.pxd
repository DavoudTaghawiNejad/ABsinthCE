cimport numpy



cdef class ProcessorGroup:
    cdef numpy.ndarray agents
    cdef int num_processors
    cdef int batch
    cdef int i
    cdef void *sender
    cdef void *in_context
    cdef void *out_context
    cdef void *out_socket
    cdef int num_agents
    cdef void *in_from_the_world
    cdef void *to_the_world
    cdef void  *from_the_world [3]


