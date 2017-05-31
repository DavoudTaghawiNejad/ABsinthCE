from cython import nogil, gil
from cython.parallel import prange, parallel
from cagent cimport CAgent
from cagent import CAgent
from libc.stdlib cimport abort, malloc, free
from libc.string cimport memcpy
from cpython.list cimport PyList_GET_ITEM
import numpy
cimport numpy
from libc.string cimport strlen
from libc.stdio cimport sprintf


ctypedef void zmq_free_fn(void *data, void *hint)


cdef extern from "zmq.h" nogil:
    enum: ZMQ_ROUTER
    enum: ZMQ_IDENTITY
    enum: ZMQ_IO_THREADS
    enum: ZMQ_SNDMORE
    enum: ZMQ_MAX_SOCKETS
    enum: ZMQ_SOCKET_LIMIT
    enum: ZMQ_DEALER
    enum: ZMQ_NOBLOCK
    enum: EAGAIN

    ctypedef void * zmq_msg_t "zmq_msg_t"

    int zmq_send (void *socket, void *buf, size_t len, int flags)
    void *zmq_ctx_new ()
    int zmq_ctx_set (void *context, int option, int optval)
    int zmq_setsockopt (void *s, int option, void *optval, size_t optvallen)
    void *zmq_socket (void *context, int type)
    int zmq_bind (void *s, char *addr)
    int zmq_ctx_get (void *context, int option_name)
    int zmq_msg_init (zmq_msg_t *msg)
    int zmq_msg_recv (zmq_msg_t *msg, void *socket, int flags)
    int zmq_msg_send (zmq_msg_t *msg, void *socket, int flags)
    int zmq_msg_more (zmq_msg_t *message)
    int zmq_msg_close (zmq_msg_t *msg)
    int zmq_errno()
    char* zmq_strerror(int errnum)
    int zmq_connect (void *s, char *addr)

#from cpython cimport PyBytes_Size, PyBytes_AsString


cdef class ProcessorGroup:
    def __init__(self, num_processors, batch, num_agents):
        cdef int rc
        cdef int io_threads = 1
        cdef char identity [6]
        cdef char *addr

        self.i = 0


        self.num_processors = num_processors
        self.batch = batch
        self.num_agents = num_agents

        a = b"inproc://server%i" % batch
        addr = a

        self.in_context = zmq_ctx_new()
        self.out_context = zmq_ctx_new()

        print('ZMQ_SOCKET_LIMIT', zmq_ctx_get(self.in_context, ZMQ_SOCKET_LIMIT))

        rc = zmq_ctx_set(self.in_context, ZMQ_IO_THREADS, 0)
        assert rc == 0
        rc = zmq_ctx_set(self.in_context, ZMQ_MAX_SOCKETS, 65530)
        assert rc == 0
        rc = zmq_ctx_set(self.out_context, ZMQ_IO_THREADS, 0)
        assert rc == 0
        rc = zmq_ctx_set(self.out_context, ZMQ_MAX_SOCKETS, 65530)
        assert rc == 0

        self.in_from_the_world = zmq_socket(self.in_context, ZMQ_DEALER)
        if self.in_from_the_world == NULL:
            raise Exception("zmq_socket out_socket" + zmq_strerror(zmq_errno()))
        print(self.batch)
        sprintf(identity, "%05i", self.batch)
        rc = zmq_setsockopt(self.in_from_the_world, ZMQ_IDENTITY, identity, strlen(identity))
        if rc != 0:
            raise Exception("zmq_setsockopt processor identity" + zmq_strerror(zmq_errno()))
        rc = zmq_bind(self.in_from_the_world, addr)
        assert rc == 0
        self.out_socket = zmq_socket(self.out_context, ZMQ_ROUTER)
        rc = zmq_bind(self.out_socket, addr)
        assert rc == 0

        self.agents = numpy.empty(num_agents, dtype='object')
        #cdef CAgent agents

        for i in range(num_agents):
            agent = CAgent(i, batch)
            socket = agent.register_socket(self.in_context, self.out_socket)
            self.agents[i] = agent

    def register_socket(self, pg):
        cdef char identity [6]
        cdef void *context
        cdef char *addr

        context = (<ProcessorGroup>pg).out_context
        socket = zmq_socket(context, ZMQ_DEALER)
        sprintf(identity, "%05i", self.batch)
        rc = zmq_setsockopt(socket, ZMQ_IDENTITY, identity, strlen(identity))
        if rc != 0:
            raise Exception("zmq_setsockopt processor identity" + zmq_strerror(zmq_errno()))
        self.from_the_world[self.i] = socket
        if socket == NULL:
            raise Exception("zmq_socket(context, ZMQ_DEALER) no socket created")
        a = b"inproc://server%i" % (<ProcessorGroup>pg).batch
        addr = a
        print(addr)
        rc = zmq_connect(socket, addr)
        if rc != 0:
            raise Exception("zmq_connect %i " % self.batch + zmq_strerror(zmq_errno()))
        self.i += 1

    def execute(self):
        print("pg", self.batch)
        cdef CAgent agent
        for agent in self.agents:
            agent.go()

    def send(self):
        for agent in self.agents:
            agent.send()

    def messaging(self):
        cdef zmq_msg_t message
        cdef int more
        cdef int rc
        cdef int num_from_the_world = 3
        cdef int i
        cdef int erno

        with nogil:
            for i in prange(num_from_the_world):
                with gil:
                    print(i)
                while True:
                    while True:
                        zmq_msg_init (&message);
                        rc = zmq_msg_recv (&message, self.from_the_world[i], ZMQ_NOBLOCK);
                        more = zmq_msg_more (&message);
                        zmq_msg_send (&message, self.in_from_the_world, ZMQ_SNDMORE if more else 0);
                        zmq_msg_close (&message);
                        if not more:
                            break
                    if rc == -1:
                        erno = zmq_errno()
                        if not erno == EAGAIN:
                            with gil:
                                raise Exception('messaging error ' + zmq_strerror(zmq_errno()))
                        break
    def recv(self):
        cdef void ** ptr= <void **> (self.agents.data)
        cdef int i

        with nogil:
            for i in prange(self.num_agents):
              (<CAgent>ptr[i]).recv()


    def __del__(self):
        #self.receiver.close()
        #self.context.term()
        pass
