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

        name = "%05i_%i" % (self.id, self.batch)


        self.receiver = zmq_socket(context, ZMQ_DEALER)
        if self.receiver == NULL:
            print("zmq_socket", zmq_strerror(zmq_errno()))

        sprintf (identity, name);
        rc = zmq_setsockopt (self.receiver, ZMQ_IDENTITY, identity, strlen (identity))
        assert rc != -1, "zmq_setsockopt"

        rc = zmq_connect(self.receiver, addr)
        assert rc != -1, "zmq_connect"
        #self._pid = getpid()
        return self.receiver


    cdef void go(self):
        self.agent.go()

    cdef void messaging(self) nogil:
        cdef int rc
        cdef char data_c [256]


        rc = zmq_recv(self.receiver, data_c, 255, flags=0)

        with gil:
            assert rc != -1, "zmq_recv"
            print(self.id, data_c)

    def __del__(self):
        pass
        #self.receiver.close()
        #self.context.term()
