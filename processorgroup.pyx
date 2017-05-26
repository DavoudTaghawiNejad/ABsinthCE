from cython import nogil
from cagent import CAgent
from cagent cimport CAgent


cdef CAgent cagent = CAgent()

with nogil:
    cagent.go()
