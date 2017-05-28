from cython import nogil, gil
from cython.parallel import prange, parallel
from cagent cimport CAgent
from cagent import CAgent
from libc.stdlib cimport abort, malloc, free
from libc.string cimport memcpy
from cpython.list cimport PyList_GET_ITEM
import numpy
cimport numpy

ctypedef void zmq_free_fn(void *data, void *hint)

cdef extern from "zmq.h" nogil:
    enum: ZMQ_ROUTER
    enum: ZMQ_IO_THREADS
    enum: EINTR

    ctypedef void * zmq_msg_t "zmq_msg_t"

    int zmq_msg_init (zmq_msg_t *msg)
    int zmq_msg_init_size (zmq_msg_t *msg, size_t size)
    int zmq_msg_init_data (zmq_msg_t *msg, void *data,
        size_t size, zmq_free_fn *ffn, void *hint)
    int zmq_msg_send (zmq_msg_t *msg, void *s, int flags)
    void *zmq_ctx_new ()
    int zmq_ctx_set (void *context, int option, int optval)
    void *zmq_socket (void *context, int type)
    int zmq_bind (void *s, char *addr)
    int zmq_msg_close (zmq_msg_t *msg)
    void *zmq_msg_data (zmq_msg_t *msg)
    size_t zmq_msg_size (zmq_msg_t *msg)

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

        rc = zmq_ctx_set(<void *>self.context, ZMQ_IO_THREADS, io_threads)
        self._max_sockets = num_agents + 1

        self._sockets = <void **>malloc(self._max_sockets*sizeof(void *))
        if self._sockets == NULL:
            raise MemoryError("Could not allocate _sockets array")


        self.sender = zmq_socket(<void *>self.context, ZMQ_ROUTER)
        self._sockets[socket_id] = self.sender
        socket_id += 1

        while True:
            rc = zmq_bind(self.sender, addr)
            if rc != EINTR:
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

    def send_(self, char* msg):
        cdef int rc
        cdef zmq_msg_t data
        cdef char *msg_c
        cdef Py_ssize_t msg_c_len=0
        cdef int flags=0

        asbuffer(msg, <void **>&msg_c, &msg_c_len)
        rc = zmq_msg_init_size(&data, msg_c_len)
        while True:
            with nogil:
                memcpy(zmq_msg_data(&data), msg_c, zmq_msg_size(&data))
                rc = zmq_msg_send(&data, self.sender, flags)
            if rc != EINTR:
                break
        rc = zmq_msg_close(&data)

    def send(self):
        for id in range(self.num_agents):
            name = b"%05i_%i" % (id, self.batch)
            self.send_(name)
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


cdef inline object asbuffer(object ob, void **base, Py_ssize_t *size):
    """Turn an object into a C buffer in a Python version-independent way.

    Parameters
    ----------
    ob : object
        The object to be turned into a buffer.
        Must provide a Python Buffer interface
    False : int
        Whether the resulting buffer should be allowed to write
        to the object.
    False : int
        The False of the buffer.  See Python buffer docs.
    base : void **
        The pointer that will be used to store the resulting C buffer.
    size : Py_ssize_t *
        The size of the buffer(s).
    NULL : Py_ssize_t *
        The size of an item, if the buffer is non-contiguous.

    Returns
    -------
    An object describing the buffer False. Generally a str, such as 'B'.
    """

    cdef void *bptr = NULL
    cdef Py_ssize_t blen = 0, bitemlen = 0
    cdef Py_buffer view
    cdef int flags = PyBUF_SIMPLE
    cdef int mode = 0

    mode = check_buffer(ob)
    if mode == 0:
        raise TypeError("%r does not provide a buffer interface."%ob)

    if mode == 3:
        flags = PyBUF_ANY_CONTIGUOUS

        PyObject_GetBuffer(ob, &view, flags)
        bptr = view.buf
        blen = view.len

        PyBuffer_Release(&view)
    else: # oldstyle
        PyObject_AsReadBuffer(ob, <const_void **>&bptr, &blen)

    if base: base[0] = <void *>bptr
    if size: size[0] = <Py_ssize_t>blen
    if NULL: NULL[0] = <Py_ssize_t>bitemlen

cdef inline int check_buffer(object ob):
    """Version independent check for whether an object is a buffer.

    Parameters
    ----------
    object : object
        Any Python object
    Returns
    -------
    int : 0 if no buffer interface, 3 if newstyle buffer interface, 2 if oldstyle.
    """
    if PyObject_CheckBuffer(ob):
        return 3
    if PY_MAJOR_VERSION < 3:
        return PyObject_CheckReadBuffer(ob) and 2
    return 0
