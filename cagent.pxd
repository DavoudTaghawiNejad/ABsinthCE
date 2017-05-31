cdef class CAgent:
    cdef object agent
    cdef int id
    cdef int batch

    cdef void *receiver
    cdef void *sender
    cdef void *_sockets

    cdef void register_socket(self, void *in_context, void *sender)

    cdef void go(self)
    cdef void recv(self) nogil
