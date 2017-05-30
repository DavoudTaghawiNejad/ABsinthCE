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
    enum: ZMQ_IO_THREADS
    enum: ZMQ_SNDMORE
    enum: ZMQ_MAX_SOCKETS
    enum: ZMQ_SOCKET_LIMIT

    int zmq_send (void *socket, void *buf, size_t len, int flags)
    void *zmq_ctx_new ()
    int zmq_ctx_set (void *context, int option, int optval)
    void *zmq_socket (void *context, int type)
    int zmq_bind (void *s, char *addr)
    int zmq_ctx_get (void *context, int option_name)

cdef extern from "Python.h":  # python 3
    int PY_MAJOR_VERSION

    cdef enum:
        PyBUF_SIMPLE
        PyBUF_ANY_CONTIGUOUS
    int  PyObject_CheckBuffer(object)
    int  PyObject_GetBuffer(object, Py_buffer *, int) except -1
    void PyBuffer_Release(Py_buffer *)

    # int PyBuffer_FillInfo(Py_buffer *view, object obj, void *buf,
    #             Py_ssize_t len, int readonly, int infoflags) except -1
    # object PyMemoryView_FromBuffer(Py_buffer *info)

    # object PyMemoryView_FromObject(object)

cdef extern from "Python.h":  # python 2
    ctypedef void const_void "const void"
    Py_ssize_t Py_END_OF_BUFFER
    int PyObject_CheckReadBuffer(object)
    int PyObject_AsReadBuffer (object, const_void **, Py_ssize_t *) except -1
    int PyObject_AsWriteBuffer(object, void **, Py_ssize_t *) except -1

    object PyBuffer_FromMemory(void *ptr, Py_ssize_t s)
    object PyBuffer_FromReadWriteMemory(void *ptr, Py_ssize_t s)

    object PyBuffer_FromObject(object, Py_ssize_t offset, Py_ssize_t size)
    object PyBuffer_FromReadWriteObject(object, Py_ssize_t offset, Py_ssize_t size)

from cpython cimport PyBytes_Size, PyBytes_AsString


cdef class ProcessorGroup:
    cdef numpy.ndarray agents
    cdef int num_processors
    cdef int batch
    cdef int _max_sockets
    cdef void *sender
    cdef void *context
    cdef void **_sockets
    cdef int num_agents

    def __init__(self, num_processors, batch, num_agents):
        cdef int rc
        cdef int io_threads = 1
        cdef int socket_id = 0

        self.num_processors = num_processors
        self.batch = batch
        self.num_agents = num_agents

        a = b"inproc://server%i" % batch
        cdef char* addr = a

        self.context = zmq_ctx_new()

        print('ZMQ_SOCKET_LIMIT', zmq_ctx_get(self.context, ZMQ_SOCKET_LIMIT))

        rc = zmq_ctx_set(self.context, ZMQ_IO_THREADS, 0)
        assert rc == 0
        rc = zmq_ctx_set(self.context, ZMQ_MAX_SOCKETS, 65530)
        assert rc == 0
        print('ZMQ_MAX_SOCKETS', zmq_ctx_get(self.context, ZMQ_MAX_SOCKETS))
        self._max_sockets = 65530

        self._sockets = <void **>malloc(self._max_sockets*sizeof(void *))
        if self._sockets == NULL:
            raise MemoryError("Could not allocate _sockets array")


        self.sender = zmq_socket(self.context, ZMQ_ROUTER)
        self._sockets[socket_id] = self.sender
        socket_id += 1

        while True:
            rc = zmq_bind(self.sender, addr)
            if rc != -1:
                break
        #self._pid = getpid()

        self.agents = numpy.empty(num_agents, dtype='object')
        #cdef CAgent agents

        for i in range(num_agents):
            agent = CAgent(i, batch)
            socket = agent.register_socket(self.context)
            self._sockets[socket_id] = socket
            socket_id += 1
            self.agents[i] = agent

    def execute(self):
        print("pg", self.batch)
        cdef CAgent agent
        for agent in self.agents:
            agent.go()

    cdef void send_(self, int id, int batch) nogil:
        cdef int rc
        cdef char name [10]
        cdef int flags=0

        sprintf(name, "%05i_%i", id, batch)

        while True:
            rc = zmq_send(self.sender, name, strlen(name), ZMQ_SNDMORE)
            rc = zmq_send(self.sender, name, strlen(name), 0)
            if rc != -1:
                break

    def send(self):
        print('begin - send', self.batch)
        cdef int id
        with nogil:
            for id in prange(self.num_agents):
               self.send_(id, self.batch)
        print('end - send', self.batch)

    def messaging(self):
        cdef int num_agents = len(self.agents)
        cdef void ** ptr= <void **> (self.agents.data)
        cdef int i

        with nogil:
            for i in prange(num_agents):
              (<CAgent>ptr[i]).messaging()

    def __del__(self):
        #self.receiver.close()
        #self.context.term()
        pass
