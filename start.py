import multiprocessing as mp
from ipyparallel.apps.ipcontrollerapp import IPControllerApp
from ipyparallel.apps.ipengineapp import IPEngineApp
from ipyparallel.error import NoEnginesRegistered
import ipyparallel as ipp
from time import sleep
from agent import Agent


def create_controller():
    IPControllerApp.launch_instance(url='inproc://test1')

def create_engine():
    IPEngineApp.launch_instance(url='inproc://test2')

def create_client(num_processes):
    c = ipp.Client(url='inproc://test1')
    while True:
        try:
            if len(c[:]) == num_processes:
                break
        except NoEnginesRegistered:
            pass
    return c[:]


if __name__ == '__main__':

    num_processes = 10

    controller = mp.Process(target=create_controller)
    controller.daemon = False
    controller.start()

    for i in range(num_processes):
        engine = mp.Process(target=create_engine)
        engine.daemon = False
        engine.start()

    agents = create_client(num_processes)


    with agents.sync_imports():
        from agent import Agent

    agent = Agent(None)

    agents.push({'name': 'wearethepeople'})


    agents.execute('agent=Agent(name)', silent=False, targets=None, block=None)
    agents.map(lambda id: agent.set_id(id), range(num_processes))
    print(agents.apply(lambda : agent.get_id()).get())
    print('end')



