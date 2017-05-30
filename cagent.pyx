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

    int zmq_recv (void *socket, void *buf, size_t len, int flags)
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


    cdef void *register_socket(self, void *context):
        cdef int name_sz
        cdef char* addr
        cdef char identity [10]

        a = b"inproc://server%i" % self.batch
        addr = a

        self.context = context


        sprintf (identity, "%05i_%i", self.id, self.batch)
        name = identity


        self.receiver = zmq_socket(context, ZMQ_DEALER)
        if self.receiver == NULL:
            raise Exception("zmq_socket " + name + zmq_strerror(zmq_errno()))

        rc = zmq_setsockopt(self.receiver, ZMQ_IDENTITY, identity, strlen(identity))
        if rc != 0:
            raise Exception("zmq_setsockopt " + name + zmq_strerror(zmq_errno()))

        rc = zmq_connect(self.receiver, addr)
        if rc != 0:
            raise Exception("zmq_connect " + name + zmq_strerror(zmq_errno()))

        #self._pid = getpid()
        return self.receiver


    cdef void go(self):
        self.agent.go()

    cdef void messaging(self) nogil:
        cdef int rc
        cdef char data_c [256]


        rc = zmq_recv(self.receiver, data_c, 255, flags=0)


        if self.id % 10000 == 0 or self.id < 10:
            with gil:
                assert rc != -1, "zmq_recv"
                print(self.id, data_c)

    def __del__(self):
        pass
        #self.receiver.close()
        #self.context.term()
