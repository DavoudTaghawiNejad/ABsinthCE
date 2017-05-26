from cython import nogil, gil
from cython.parallel import prange, parallel
from cagent cimport CAgent
from cagent import CAgent
from libc.stdlib cimport abort, malloc, free
from cpython.list cimport PyList_GET_ITEM
import numpy
cimport numpy

cdef void func(int * lb) nogil:
    pass

cdef class ProcessorGroup:
    cdef numpy.ndarray agents
    cdef int num_processors
    cdef int batch
    def __init__(self, num_processors, batch):
        self.num_processors = num_processors
        self.batch = batch
        self.agents = numpy.empty(10, dtype='object')
        for i in range(10):
            agent = CAgent(i, batch)
            self.agents[i] = agent
            # agents_in_c.push_back(agent)

    def execute(self):
        print("pg", self.batch)
        cdef CAgent agent
        for agent in self.agents:
            agent.go()

    def messaging(self):
        #with nogil, parallel():
        #        r = (<CAgent>self.agents[a]).messaging()

        cdef int num_agents = len(self.agents)
        cdef void ** ptr= <void **> (self.agents.data)
        cdef int i

        with nogil:
            for i in prange(num_agents):
              (<CAgent>ptr[i]).messaging()

