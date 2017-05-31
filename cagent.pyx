from cython import gil
from agent import Agent

from libc.stdlib cimport malloc
from libc.string cimport strlen
from libc.stdio cimport sprintf


ctypedef void zmq_free_fn(void *data, void *hint)

cdef extern from "zmq.h" nogil:
    enum: ZMQ_DEALER
    enum: ZMQ_IDENTITY
    enum: ZMQ_IO_THREADS
    enum: ZMQ_ROUTER
    enum: ZMQ_SNDMORE
    enum: ZMQ_ROUTER

    int zmq_recv (void *socket, void *buf, size_t len, int flags)
    int zmq_send (void *socket, void *buf, size_t len, int flags)
    void *zmq_ctx_new ()
    int zmq_ctx_set (void *context, int option, int optval)
    void *zmq_socket (void *context, int type)
    int zmq_connect (void *s, char *addr)
    int zmq_setsockopt (void *s, int option, void *optval, size_t optvallen)
    int zmq_errno()
    char* zmq_strerror(int errnum)

from cpython cimport PyBytes_Size, PyBytes_AsString

cdef class CAgent:
    def __cinit__(self, id, batch):
        cdef int rc
        self.agent = Agent(id, batch)
        self.id = id
        self.batch = batch


    cdef void register_socket(self, void *in_context, void *sender):
        cdef int name_sz
        cdef char* addr
        cdef char identity [12]

        a = b"inproc://server%i" % self.batch
        addr = a

        sprintf (identity, "%05i_%05i", self.id, self.batch)
        name = identity


        self.receiver = zmq_socket(in_context, ZMQ_DEALER)
        if self.receiver == NULL:
            raise Exception("zmq_socket " + name + zmq_strerror(zmq_errno()))

        rc = zmq_setsockopt(self.receiver, ZMQ_IDENTITY, identity, strlen(identity))
        if rc != 0:
            raise Exception("zmq_setsockopt " + name + zmq_strerror(zmq_errno()))

        rc = zmq_connect(self.receiver, addr)
        if rc != 0:
            raise Exception("zmq_connect " + name + zmq_strerror(zmq_errno()))


        self.sender = sender

    cdef void go(self):
        self.agent.go()

    def send(self):
        cdef int rc
        cdef char processor_group_name [6]
        cdef char name [12]
        cdef int flags=0

        sprintf(processor_group_name, "%05i", (self.batch + 1) % 3)
        sprintf(name, "%05i_%05i", self.id, (self.batch + 1) % 3)

        rc = zmq_send(self.sender, processor_group_name, strlen(processor_group_name), ZMQ_SNDMORE)
        if rc == -1:
                raise Exception("zmq_send 0 %i_%i " % (self.batch, self.id) + zmq_strerror(zmq_errno()))
        rc = zmq_send(self.sender, name, strlen(name), ZMQ_SNDMORE)
        if rc == -1:
                raise Exception("zmq_send 1 %i_%i " % (self.batch, self.id) + zmq_strerror(zmq_errno()))
        rc = zmq_send(self.sender, "aayyxx", strlen("aayyxx"), 0)
        if rc == -1:
                raise Exception("zmq_send 2 %i_%i " % (self.batch, self.id) + zmq_strerror(zmq_errno()))
        print self.id, self.batch

    cdef void recv(self) nogil:
        cdef int rc
        cdef char data_c [256]


        rc = zmq_recv(self.receiver, data_c, 255, flags=0)

        with gil:
            assert rc != -1, "zmq_recv"
            print(self.id, data_c)
            print('heer')


    def __del__(self):
        pass
        #self.receiver.close()
        #self.context.term()
