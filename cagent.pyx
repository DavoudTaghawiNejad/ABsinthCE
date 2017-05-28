from cython import gil
from agent import Agent

from libc.stdlib cimport malloc
from libc.string cimport memcpy

ctypedef void zmq_free_fn(void *data, void *hint)

cdef extern from "zmq.h" nogil:
    enum: ZMQ_DEALER
    enum: ZMQ_IDENTITY
    enum: ZMQ_IO_THREADS
    enum: EINTR

    ctypedef void * zmq_msg_t "zmq_msg_t"

    int zmq_msg_init (zmq_msg_t *msg)
    int zmq_msg_init_size (zmq_msg_t *msg, size_t size)
    int zmq_msg_init_data (zmq_msg_t *msg, void *data,
        size_t size, zmq_free_fn *ffn, void *hint)
    int zmq_msg_recv (zmq_msg_t *msg, void *s, int flags)
    void *zmq_ctx_new ()
    int zmq_ctx_set (void *context, int option, int optval)
    void *zmq_socket (void *context, int type)
    int zmq_connect (void *s, char *addr)
    int zmq_msg_close (zmq_msg_t *msg)
    void *zmq_msg_data (zmq_msg_t *msg)
    size_t zmq_msg_size (zmq_msg_t *msg)
    int zmq_setsockopt (void *s, int option, void *optval, size_t optvallen)

from cpython cimport PyBytes_Size

from libc.stdio cimport printf

cdef class CAgent:
    def __cinit__(self, id, batch):
        cdef int rc
        self.agent = Agent(id, batch)
        self.id = id
        self.batch = batch

        name = b"%05i_%i" % (self.id, self.batch)
        self.name = name
        #print('name', self.name)

    cdef void *register_socket(self, void *context):

        a = b"inproc://server%i" % self.batch
        cdef char* addr = a

        self.context = context

        self.receiver = zmq_socket(self.context, ZMQ_DEALER)

        while True:
            rc = zmq_setsockopt(self.receiver, ZMQ_IDENTITY, self.name, PyBytes_Size(self.name))
            if rc != EINTR:
                break

        while True:
            rc = zmq_connect(self.receiver, addr)
            if rc != EINTR:
                break
        #self._pid = getpid()

        return self.receiver


    cdef void go(self):
        self.agent.go()

    cdef void messaging(self) nogil:
        cdef int rc
        cdef zmq_msg_t zmq_msg
        rc = zmq_msg_init (&zmq_msg)
        cdef char *data_c = NULL
        cdef Py_ssize_t data_len_c
        while True:
            rc = zmq_msg_recv(&zmq_msg, self.receiver, flags=0)
            if rc != EINTR:
                break

        data_c = <char *>zmq_msg_data(&zmq_msg)
        data_len_c = zmq_msg_size(&zmq_msg)
        zmq_msg_close(&zmq_msg)
        with gil:
            print(data_len_c, data_c[0], data_c[1], data_c[2])

    def __del__(self):
        pass
        #self.receiver.close()
        #self.context.term()
