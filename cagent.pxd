cdef class CAgent:
    cdef object agent

    cdef void go(self) nogil

