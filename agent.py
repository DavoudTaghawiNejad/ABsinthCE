class Agent:
    def __init__(self, id, batch):
        self.id = id
        self.batch = batch

    def go(self):
        if self.id == 0:
            print('go python agent 0', self.batch)
