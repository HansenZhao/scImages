import numpy as np
import os
import time

class fix_size_queue(object):
    def __init__(self,size,init_element=None):
        self.data = []
        for m in range(size):
            self.data.append(init_element)
    def push(self,ele):
        self.data.append(ele)
        self.data.pop(0)
    def mean(self):
        return np.mean(self.data)
    @property
    def size(self):
        return len(self.data)

class parameters_record(object):
    def __init__(self,**kwargs):
        self.parameter_dict = kwargs
        self.parameter_dict['time'] = time.ctime()
    def write_config(self,fname,fpath=None):
        if not fpath:
            fpath = os.getcwd()
        folder = os.path.exists(fpath)
        if not folder:
            os.makedirs(fpath)
        with open(fpath+'/'+fname,'w') as file:
            for key,value in self.parameter_dict.items():
                file.write(key+'='+str(value)+'\n')
