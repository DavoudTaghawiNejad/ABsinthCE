cdef class CAgent:
    cdef object agent
    cdef int id
    cdef int batch

    cdef void go(self)
    cdef void messaging(self) nogil

