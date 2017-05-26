from agent import Agent

cdef class CAgent(object):

    def __init__(self):
        self.agent = Agent()
        pass

    cdef void go(self) nogil:
        #self.agent.go()
        cdef int i
        i += 1
        with gil:
            print('hello')

