from cpython cimport PyBytes_FromStringAndSize
from agent import Agent


cdef class CAgent:
    cdef object agent
    cdef int id
    cdef int batch
    cdef char *name

    cdef int _max_sockets

    cdef void *receiver
    cdef object context
    cdef void *_sockets

    cdef void go(self)
    cdef void messaging(self) nogil
