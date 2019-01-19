import javabridge
import bioformats
import numpy as np
import scipy.io as sio
import tensorflow as tf

# javabridge.start_vm(class_path=bioformats.JARS)
#
# r = bioformats.get_image_reader(None,path='J:\\CNN-Cell-profile-XRZhang\\result\\20181106\\MCF7-NuLyTrans-1_R3D.dv')
#
# meta_str = bioformats.get_omexml_metadata(path='J:\\CNN-Cell-profile-XRZhang\\result\\20181106\\MCF7-NuLyTrans-1_R3D.dv')
# meta_xml = bioformats.omexml.OMEXML(meta_str)
# n_channel = meta_xml.image(0).Pixels.SizeC
# n_steps = meta_xml.image(0).Pixels.SizeT
# n_slice = meta_xml.image(0).Pixels.SizeZ
# n_image_h = meta_xml.image(0).Pixels.SizeY
# n_image_w = meta_xml.image(0).Pixels.SizeX
# im = r.read(c=None,z=0,t=0,rescale=False)
# im = np.divide(im,np.max(im,axis=(0,1),keepdims=True),dtype=np.float32)

# print('s')

class dv_images(object):
    def __init__(self,dv_path,tag_path=None, cache_all = True, speak = True):
        self.dv_path = dv_path
        self.tag_path = tag_path
        self.cache_all = cache_all
        javabridge.start_vm(class_path=bioformats.JARS)
        if speak:
            print('Getting DV metadata....')
        self.meta_str = bioformats.get_omexml_metadata(path=self.dv_path)
        if speak:
            print('Solving metadata...')
        self.meta_xml = bioformats.omexml.OMEXML(self.meta_str)
        if cache_all:
            if speak:
                print('Caching all images')
            self.cache_image = self.__read_image()
        else:
            self.cache_image = np.empty(0)
        self.reader = bioformats.get_image_reader(None, self.dv_path)
        if tag_path is not None:
            tmp = sio.loadmat(tag_path)['tag']
            if len(tmp.shape) < 3:
                tmp = np.reshape(tmp,newshape=(1,tmp.shape[0],tmp.shape[1]))
            self.tags = tmp.astype(np.int32)
        else:
            self.tags = np.empty(0)
    def __del__(self):
        print('del func called')
        javabridge.kill_vm()
        self.reader.close()
    def __read_image(self,t=None,z=None,c=None):
        if t is None:
            t = range(self.n_steps)
        if z is None:
            z = range(self.n_slice)
        if c is None:
            cache_image = np.zeros(shape=(len(t), self.image_h, self.image_w, len(z), self.n_channel),
                                   dtype=np.float32)
            for ct in range(len(t)):
                for cz in range(len(z)):
                    try:
                        im = self.reader.read(z=z[cz],t=t[ct],rescale=False) #HWC
                        cache_image[ct,:,:,cz,:] = np.divide(im,np.median(im,axis=(0,1),keepdims=True),dtype=np.float32)
                    except AttributeError:
                        print('s')
        else:
            cache_image = np.zeros(shape=(len(t), self.image_h, self.image_w, len(z), len(c)),
                                   dtype=np.float32)
            for ct in range(len(t)):
                for cz in range(len(z)):
                    for cc in range(len(c)):
                        im = self.reader.read(c=c[cc],z=z[cz],t=t[ct],rescale=False) #HW
                        cache_image[ct,:,:,cz,cc] = np.divide(im,np.median(im,axis=(0,1),keepdims=True),dtype=np.float32)
        return cache_image
    def clear_cache(self):
        self.cache_image = np.empty(0)
    def cache_images(self,t=None,z=None,c=None):
        self.cache_image = self.__read_image(t=t,z=z,c=c)
    def get_NHWC_image(self,idx=None,get_tag=False,fix_transform = None):
        if not len(self.cache_image):
            raise ValueError('no cached image found!')
        if get_tag:
            assert self.n_cached_image == self.n_tag, "inconsist tag number: {tn} and image number {imn}".format(tn=self.n_tag,imn=self.n_cached_image)
            if idx is None:
                y = self.tags
            else:
                y = self.tags[idx,...]
        else:
            y = []
        if idx is None:
            images = np.reshape(self.cache_image,newshape=(self.n_cached_image,self.image_h,self.image_w,-1))
        else:
            images =  np.reshape(self.cache_image[idx,...], newshape=(len(idx), self.image_h, self.image_w, -1))
        if fix_transform is None:
            I = np.random.choice(range(8),size=images.shape[0])
        else:
            I = np.ones(shape=images.shape[0],dtype=np.int32)*fix_transform
        for i in range(images.shape[0]):
            images[i,...] = dv_images.image_transform(images[i,...],I[i])
            if get_tag:
                y[i,...] = dv_images.image_transform(y[i,...],I[i])
        return images,y
    def make_TFRecords(self,file_path,idx=None):
        writer = tf.python_io.TFRecordWriter(file_path)
        print('write begin...')
        X,y = self.get_NHWC_image(idx=idx,get_tag=True,fix_transform=0)
        count = 0
        for image,label in zip(X,y):
            example = self._make_tfr_example(image.tobytes(),label.tobytes())
            writer.write(example.SerializeToString())
            count += 1
            if count%5 == 0:
                print('{count:d}/{total:d}'.format(count=count,total=X.shape[0]))
        writer.close()
        print('write done')
    def check_this_tfrecord(self, fpath, X_type=np.float32, y_type=np.int32):
        return dv_images.check_tfrecord(fpath,[self.image_h,self.image_w],X_type,y_type)
    def _make_tfr_example(self,image,tag):
        return tf.train.Example(features=tf.train.Features(feature={
            'image':tf.train.Feature(bytes_list=tf.train.BytesList(value=[image])),
            'label':tf.train.Feature(bytes_list=tf.train.BytesList(value=[tag]))
        }))
    def close(self):
        self.reader.close()
        javabridge.kill_vm()
    @staticmethod
    def image_transform(im,option):
        #[HWC]
        if option < 4:
            return np.rot90(im,k=option,axes=(1,0))
        else:
            return {
                4: lambda im: im[::-1, ...],
                5: lambda im: im[:, ::-1, ...],
                6: lambda im: np.rot90(im,k=1,axes=(1,0))[::-1, ...],
                7: lambda im: np.rot90(im,k=1,axes=(1,0))[:, ::-1, ...]
            }[option](im)
    @staticmethod
    def check_tfrecord(fpath,imsize,X_type=np.float32,y_type=np.int32):
        tf_iter = tf.python_io.tf_record_iterator(path=fpath)
        recoverd_res = []
        for string_record in tf_iter:
            example = tf.train.Example()
            example.ParseFromString(string_record)
            image = example.features.feature['image'].bytes_list.value[0]
            tag = example.features.feature['label'].bytes_list.value[0]
            image_1d = np.fromstring(image, dtype=X_type)
            tag_1d = np.fromstring(tag, dtype=y_type)
            recoverd_res.append((image_1d.reshape([imsize[0], imsize[1], -1]),
                                 tag_1d.reshape([imsize[0], imsize[1]])))
        return recoverd_res
    @staticmethod
    def get_tfrecord_sequence(fpath,imsize,label_size,X_type=np.float32,y_type=np.int32):
        _,serialized_example = tf.TFRecordReader().read(fpath)
        features = tf.parse_single_example(serialized_example,features={
            'image': tf.FixedLenFeature([], tf.string),
            'label': tf.FixedLenFeature([], tf.string)
        })
        image = tf.decode_raw(features['image'],X_type)
        label = tf.decode_raw(features['label'],y_type)

        image_reshaped = tf.reshape(image,tf.stack(imsize))
        label_reshaped = tf.reshape(label,tf.stack(label_size))
        images,labels = tf.train.shuffle_batch([image_reshaped,label_reshaped],batch_size=4,capacity=100,num_threads=2,min_after_dequeue=10)
        return images,labels
    @property
    def n_channel(self):
        return self.meta_xml.image(0).Pixels.SizeC
    @property
    def n_steps(self):
        return self.meta_xml.image(0).Pixels.SizeT
    @property
    def n_slice(self):
        return self.meta_xml.image(0).Pixels.SizeZ
    @property
    def image_h(self):
        return self.meta_xml.image(0).Pixels.SizeY
    @property
    def image_w(self):
        return self.meta_xml.image(0).Pixels.SizeX
    @property
    def n_cached_image(self):
        return len(self.cache_image)
    @property
    def n_cached_channel(self):
        return self.cache_image.shape[3]*self.cache_image.shape[4] #[NHWC]
    @property
    def n_tag(self):
        return self.tags.shape[0]


