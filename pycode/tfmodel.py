import tensorflow as tf
import re


class cellIdNet():
    def __init__(self,filter_size,nfilters,fcn = False,pooling_size = 2,keep_prob=1,
                 init_std = 0.02):
        if len(nfilters) - len(filter_size) != 1:
            raise ValueError('Invalid nfilter size, should larger than the size of filter_size!')
        self.filter_size = filter_size
        self.nfilters = nfilters
        self.fcn = fcn
        self.pooling_size = pooling_size
        self.keep_prob = keep_prob
        self.init_std = init_std
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
    def __init__(self,construct_str,pooling_size=2,init_std = 0.02):
        self.pooling_size = pooling_size
        self.construct_str = construct_str
        self.init_std = init_std
        self.W = []
        self.b = []
        self.size = []

    def inference(self,images,keep_prob=1.0,silence=True,regularizer=None):
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
                                                  initializer=tf.truncated_normal(shape=(fs,fs,self.size[-1],nc),stddev=self.init_std),
                                                  regularizer=regularizer))
                    self.b.append(tf.get_variable(name='b'+str(i),
                                                  initializer=tf.constant(0.0,shape=[nc]),
                                                  regularizer=regularizer))
                    if c_str.startswith('s'):
                        current_act = tf.nn.bias_add(tf.nn.conv2d(current_act,self.W[-1],strides=[1,1,1,1],padding='SAME'),self.b[-1])
                    else:
                        current_act = tf.nn.bias_add(tf.nn.conv2d(current_act,self.W[-1],strides=[1,1,1,1],padding='VALID'),self.b[-1])
                    self.size.append(nc)
                    tf.add_to_collection('weight',self.W[-1])
                    tf.add_to_collection('weight',self.b[-1])
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
                                                                                  stddev=self.init_std),
                                                                                  regularizer=regularizer))
                    self.b.append(tf.get_variable(name='b' + str(i),
                                                  initializer=tf.constant(0.0, shape=[nnode]),
                                                  regularizer=regularizer))
                    current_act = tf.nn.bias_add(tf.matmul(current_act,self.W[-1]),self.b[-1])
                    self.size.append(nnode)
                    tf.add_to_collection('weight',self.W[-1])
                    tf.add_to_collection('weight',self.b[-1])
                else:
                    raise ValueError('cannot solve layer: ' + c_str)
            else:
                raise ValueError('cannot solve layer: ' + c_str)
            if not silence:
                print('solved '+c_str+str(current_act.shape))
            net[c_str + str(i)] = current_act
        self.W = []
        self.size = []
        self.b = []
        return current_act,net

    @property
    def nLayer(self):
        return len(self.construct_str)

class GeneralNetv2(object):
    def __init__(self,construct_str,pooling_size=2,init_std=0.02):
        self.pooling_size = pooling_size
        self.construct_str = construct_str
        self.init_std = init_std
    def inference(self,images,keep_prob=1.0,silence=True,regularizer=None):
        tensor_dict = {}
        channel_cache = []
        channel_dict = {}
        tensor_dict['raw'] = images #[NHWC]
        channel_dict['raw'] = int(images.shape[3])
        channel_cache.append(int(images.shape[3]))
        current_act = images
        for i,c_str in enumerate(self.construct_str):
            m = re.search('{(?P<name>\S+):(?P<comd>\S+)}(\((?P<param>\S+)\))*',c_str)
            if m:
                comd = m.groupdict()['comd']
                name = m.groupdict()['name']
                if name in tensor_dict.keys():
                    raise ValueError('duplicate defined {name}'.format(name=name))
                if comd.startswith('conv') or comd.startswith('sconv'):
                    param_set = m.groupdict()['param'].split(',')
                    filter_size = int(param_set[0])
                    filter_num = int(param_set[1])
                    W = tf.get_variable(name=name+'_W',
                                        initializer=tf.truncated_normal(shape=(filter_size, filter_size, channel_cache[-1], filter_num),
                                                                                  stddev=self.init_std),regularizer=regularizer)
                    b = tf.get_variable(name=name+'_b',initializer=tf.constant(0.0, shape=[filter_num]),regularizer=regularizer)
                    if comd.startswith('s'):
                        current_act = tf.nn.bias_add(tf.nn.conv2d(current_act, W, strides=[1, 1, 1, 1], padding='SAME'), b)
                    else:
                        current_act = tf.nn.bias_add(tf.nn.conv2d(current_act, W, strides=[1, 1, 1, 1], padding='VALID'),b)
                    tf.add_to_collection('weight', W)
                    tf.add_to_collection('weight', b)
                elif comd.startswith('relu'):
                    current_act = tf.nn.relu(current_act) #[NHWC]
                    filter_num = channel_cache[-1]
                elif comd.startswith('pool'):
                    current_act = tf.nn.max_pool(current_act, ksize=[1, self.pooling_size, self.pooling_size, 1],
                                                 strides=[1, 2, 2, 1], padding='VALID')
                    filter_num = channel_cache[-1]
                elif comd.startswith('dropout'):
                    current_act = tf.nn.dropout(current_act, keep_prob=keep_prob)
                    filter_num = channel_cache[-1]
                elif comd.startswith('batchnor'):
                    current_act = tf.layers.batch_normalization(current_act)
                    filter_num = channel_cache[-1]
                elif comd.startswith('flat'):
                    current_act = tf.layers.flatten(current_act)
                    filter_num = int(current_act.shape[1])
                elif comd.startswith('dense'):
                    param_set = m.groupdict()['param']
                    nnode = int(param_set)
                    W = tf.get_variable(name=name+'_W',initializer=tf.truncated_normal(shape=(channel_cache[-1], nnode),
                                                                                       stddev=self.init_std),regularizer=regularizer)
                    b = tf.get_variable(name=name+'_b',initializer=tf.constant(0.0, shape=[nnode]),regularizer=regularizer)
                    current_act = tf.nn.bias_add(tf.matmul(current_act, W), b)
                    filter_num = nnode
                    tf.add_to_collection('weight', W)
                    tf.add_to_collection('weight', b)
                elif comd.startswith('deconv'):
                    param_set = m.groupdict()['param'].split(',') # up,up_ratio,kernal_size / ref,strides,kernal_size /man,outH,outC,strides,kernal_size
                    if param_set[0] == 'up' and len(param_set) == 3:
                        cur_shape = current_act.get_shape().as_list() #[NHWC]
                        up_ratio = int(param_set[1])
                        s = up_ratio
                        out_size = cur_shape
                        out_size[1] *= up_ratio
                        out_size[2] *= up_ratio
                        kernal_size = int(param_set[2])
                    elif param_set[0] in tensor_dict.keys() and len(param_set) == 3:
                        out_size = tensor_dict[param_set[0]].get_shape().as_list()
                        out_size[0] = tf.shape(tensor_dict[param_set[0]])[0]
                        s = int(param_set[1])
                        kernal_size = int(param_set[2])
                    elif param_set[0] == 'mann' and len(param_set) == 5:
                        # cur_shape = current_act.get_shape().as_list()
                        # out_size = [cur_shape[0],int(param_set[1]),int(param_set[1]),int(param_set[2])]
                        out_size = [tf.shape(current_act)[0], int(param_set[1]), int(param_set[1]), int(param_set[2])]
                        s = int(param_set[3])
                        kernal_size = int(param_set[4])
                    else:
                        raise ValueError('cannot solve layer: ' + c_str)
                    filter_num = out_size[3]
                    W = tf.get_variable(name=name + '_W',initializer=tf.truncated_normal(
                        shape=(kernal_size, kernal_size,out_size[3],channel_cache[-1]),stddev=self.init_std), regularizer=regularizer)
                    b = tf.get_variable(name=name + '_b', initializer=tf.constant(0.0, shape=[out_size[3]]),regularizer=regularizer)
                    current_act = tf.nn.bias_add(tf.nn.conv2d_transpose(current_act, W, out_size,
                                                                  strides=[1, s, s, 1], padding="SAME"),b)
                    tf.add_to_collection('weight', W)
                    tf.add_to_collection('weight', b)
                elif comd.startswith('fuse'):
                    param_set = m.groupdict()['param'].split(',')
                    if len(param_set) == 2 and param_set[0] in tensor_dict.keys() and param_set[1] in tensor_dict.keys():
                        current_act = tf.add(tensor_dict[param_set[0]],tensor_dict[param_set[1]])
                        filter_num = current_act.get_shape().as_list()[3]
                    else:
                        raise ValueError('cannot solve layer: ' + c_str)
                else:
                    raise ValueError('cannot solve layer: ' + c_str)
                channel_cache.append(filter_num)
                tensor_dict[name] = current_act
                channel_dict[name] = filter_num
                if not silence:
                    print('solved ' + c_str + str(current_act.shape))
            else:
                raise ValueError('unsolved construct options: {opt}'.format(opt=c_str))
        return current_act



