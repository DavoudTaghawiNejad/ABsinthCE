import multiprocessing as mp
from ipyparallel.apps.ipcontrollerapp import IPControllerApp
from ipyparallel.apps.ipengineapp import IPEngineApp
import ipyparallel as ipp
from time import sleep

def create_controller():
    IPControllerApp.launch_instance(url='inproc://test1')

def create_engine():
    IPEngineApp.launch_instance(url='inproc://test2')

def create_client():
    c = ipp.Client(url='inproc://test1')
    sleep(10)

    print(c.ids)


if __name__ == '__main__':

    num_processes = 10

    controller = mp.Process(target=create_controller)
    controller.daemon = False
    controller.start()

    for i in range(num_processes):
        engine = mp.Process(target=create_engine)
        engine.daemon = False
        engine.start()

    create_client()

