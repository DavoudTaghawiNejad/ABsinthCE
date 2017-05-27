from processorgroup import ProcessorGroup
import multiprocessing as mp
from multiprocessing.managers import BaseManager


class MyManager(BaseManager):
    pass

def execute_wrapper(inp):
    return inp.execute()

processes = 3


pool = mp.Pool(processes)
MyManager.register('ProcessorGroup', ProcessorGroup)
managers = []
_processor_groups = []
for i in range(processes):
    manager = MyManager()
    manager.start()
    managers.append(manager)
    pg = manager.ProcessorGroup(processes, batch=i, num_agents=50)
    _processor_groups.append(pg)


out = pool.map(execute_wrapper, _processor_groups, chunksize=1)


for pg in _processor_groups:
    pg.send()

for pg in _processor_groups:
    pg.messaging()

print("hend")
