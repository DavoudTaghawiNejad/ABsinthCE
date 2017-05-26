class Agent:
    def __init__(self, id, batch):
        self.id = id
        self.batch = batch

    def go(self):
        print('go python agent ', self.id, self.batch)
