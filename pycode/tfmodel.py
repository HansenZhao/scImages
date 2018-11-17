import tensorflow as tf
import re


class cellIdNet():
    def __init__(self,filter_size,nfilters,fcn = False,pooling_size = 2,keep_prob=1):
        if len(nfilters) - len(filter_size) != 1:
            raise ValueError('Invalid nfilter size, should larger than the size of filter_size!')
        self.filter_size = filter_size
        self.nfilters = nfilters
        self.fcn = fcn
        self.pooling_size = pooling_size
        self.keep_prob = keep_prob
        self.W = []
        self.b = []
        self.z = []
        self.pool = []
        self.a = []

    def inference(self,images):
        # images [batch,height,weight,channel] #filter [h,w,prev_channel,channel]
        self.a.append(images)
        for i,fs in zip(range(len(self.filter_size)),self.filter_size):
            self.W.append(tf.get_variable(name='W'+i,initializer=tf.truncated_normal(shape=(fs,fs,self.nfilters[i],self.nfilters[i+1]),stddev=0.02)))
            self.b.append(tf.get_variable(name='b'+i,initializer=tf.constant(0.0,shape=self.nfilters[i+1])))
            self.z.append(tf.nn.conv2d(self.a[-1],self.W[-1],strides=[1,1,1,1],padding='SAME')+self.b[-1])
            if i != (len(self.nfilters) - 2):
                self.a.append(tf.nn.dropout(tf.nn.relu(self.z[-1],name='a'+i),keep_prob=self.keep_prob))
        return self.z[-1]


class GeneralNet:
    def __init__(self,construct_str,pooling_size=2):
        self.pooling_size = pooling_size
        self.construct_str = construct_str
        self.W = []
        self.b = []
        self.size = []

    def inference(self,images,keep_prob=1.0):
        current_act = images #[b,h,w,c]
        self.size.append(int(images.shape[3]))
        net = {}
        for i,c_str in enumerate(self.construct_str):
            if c_str.startswith('conv') or c_str.startswith('sconv'):
                m = re.search('\S+(?P<fs>\d+)-(?P<nc>\d+)',c_str)
                if m:
                    fs = int(m.groupdict()['fs'])
                    nc = int(m.groupdict()['nc'])
                    self.W.append(tf.get_variable(name='W'+ str(i),
                                                  initializer=tf.truncated_normal(shape=(fs,fs,self.size[-1],nc),stddev=0.02)))
                    self.b.append(tf.get_variable(name='b'+str(i),
                                                  initializer=tf.constant(0.0,shape=[nc])))
                    if c_str.startswith('s'):
                        current_act = tf.nn.bias_add(tf.nn.conv2d(current_act,self.W[-1],strides=[1,1,1,1],padding='SAME'),self.b[-1])
                    else:
                        current_act = tf.nn.bias_add(tf.nn.conv2d(current_act,self.W[-1],strides=[1,1,1,1],padding='VALID'),self.b[-1])
                    self.size.append(nc)
                else:
                    raise ValueError('cannot solve layer: ' + c_str)
            elif c_str.startswith('relu'):
                current_act = tf.nn.relu(current_act)
            elif c_str.startswith('pool'):
                current_act = tf.nn.max_pool(current_act,ksize=[1,self.pooling_size,self.pooling_size,1],strides=[1,2,2,1],padding='VALID')
            elif c_str.startswith('dropout'):
                current_act = tf.nn.dropout(current_act,keep_prob=keep_prob)
            elif c_str.startswith('batchnor'):
                current_act = tf.layers.batch_normalization(current_act)
            elif c_str.startswith('flat'):
                current_act = tf.layers.flatten(current_act)
                self.size.append(int(current_act.shape[1]))
            elif c_str.startswith('dense'):
                m = re.search('dense(?P<nnode>\d+)', c_str)
                if m:
                    nnode = int(m.groupdict()['nnode'])
                    self.W.append(tf.get_variable(name='W' + str(i),
                                                  initializer=tf.truncated_normal(shape=(self.size[-1], nnode),
                                                                                  stddev=0.02)))
                    self.b.append(tf.get_variable(name='b' + str(i),
                                                  initializer=tf.constant(0.0, shape=[nnode])))
                    current_act = tf.nn.bias_add(tf.matmul(current_act,self.W[-1]),self.b[-1])
                    self.size.append(nnode)
                else:
                    raise ValueError('cannot solve layer: ' + c_str)
            else:
                raise ValueError('cannot solve layer: ' + c_str)
            print('solved '+c_str+str(current_act.shape))
            net[c_str + str(i)] = current_act
        return current_act,net

    @property
    def nLayer(self):
        return len(self.construct_str)
