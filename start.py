from processorgroup import ProcessorGroup
import multiprocessing as mp
from multiprocessing.managers import BaseManager
import timeit

class MyManager(BaseManager):
    pass

def execute_wrapper(inp):
    return inp.execute()

processes = 10


pool = mp.Pool(processes)
MyManager.register('ProcessorGroup', ProcessorGroup)
managers = []
_processor_groups = []
for i in range(processes):
    manager = MyManager()
    manager.start()
    managers.append(manager)
    pg = manager.ProcessorGroup(batch=i, num_agents=500, num_processes=processes)  # !!!!!!!!!!!!!!!!!!!!!!!!
    _processor_groups.append(pg)

print 'begin'
for x in _processor_groups:
    for y in _processor_groups:
        x.register_socket(y)

print 'endbegin'
out = pool.map(execute_wrapper, _processor_groups, chunksize=1)
print('send:')
st = timeit.default_timer()
for pg in _processor_groups:
    pg.send()
print("messaging:")
for pg in _processor_groups:
    pg.messaging()
print('recv:')
for pg in _processor_groups:
    pg.recv()

print('timeit', timeit.default_timer() - st)
print("end")
