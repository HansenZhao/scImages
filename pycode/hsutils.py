import numpy as np
import os
import time
import tensorflow as tf

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
    def read_config(self,fpath):
        tmp=fpath.split('\\')
        model_name = tmp[-1]
        full_path = fpath + '\\config\\' + model_name + '.txt'
        if not os.path.exists(full_path):
            raise ValueError('Cannot found file {path}'.format(path=full_path))
        config_dic = {}
        with open(full_path,'r') as fileReader:
            for line in fileReader:
                # print(line)
                tmp = line.split('=')
                config_dic[tmp[0]] = tmp[1].rstrip()
        return config_dic

class hyparam_search_csv_record(object):
    def __init__(self,params_name,fpath=None,fname=None):
        if fpath is None:
            fpath = os.getcwd()
        if fname is None:
            fname = 'BOSeries.csv'
        self.fpath = fpath
        self.fname = fname
        self.params_name = params_name
        self.params_name.append('performance')
        self.params_name.append('loss')
        self.params_name.append('duration')
        self.cache_dict = {}
        self.__mk_file()
    def __mk_file(self):
        folder = os.path.exists(self.fpath)
        if not folder:
            os.makedirs(self.fpath)
        with open(self.fpath + '/' + self.fname, 'w') as file:
            for words in self.params_name:
                file.write(words+',')
            file.write('\n')
    def assign_record_with_name(self,keyword_dict):
        for key in keyword_dict:
            self.cache_dict[key] = keyword_dict[key]
    def commit_record(self):
        for word in self.params_name:
            assert word in self.cache_dict.keys(), 'Cannot found word: {w}'.format(w=word)
        with open(self.fpath+'/'+self.fname,'a') as file:
            for word in self.params_name:
                file.write('{value:.3f},'.format(value=self.cache_dict.get(word)))
            file.write('\n')
        self.cache_dict = {}



