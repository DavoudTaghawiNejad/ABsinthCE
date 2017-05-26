from cython import gil
from agent import Agent

cdef class CAgent:

    def __init__(self, id, batch):
        self.agent = Agent(id, batch)
        self.id = id
        self.batch = batch

    cdef void go(self):
        self.agent.go()

    cdef void messaging(self) nogil:
        cdef int i = 0
        i += 1
        with gil:
            print(self.id, self.batch)



