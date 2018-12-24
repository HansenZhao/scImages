import javabridge
import bioformats
import numpy as np
import scipy.io as sio

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
            self.tags = sio.loadmat(tag_path)['tag']
        else:
            self.tags = np.empty(0)
    def __del__(self):
        print('del func called')
        self.close()
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
                        im = self.reader.read(c=c[cc],z=z[ct],t=t[ct],rescale=False) #HW
                        cache_image[ct,:,:,cz,cc] = np.divide(im,np.median(im,axis=(0,1),keepdims=True),dtype=np.float32)
        return cache_image
    def clear_cache(self):
        self.cache_image = np.empty(0)
    def cache_images(self,t=None,z=None,c=None):
        self.cache_image = self.__read_image(t=t,z=z,c=c)
    def get_NHWC_image(self,idx=None,get_tag=False):
        if not len(self.cache_image):
            raise ValueError('no cached image found!')
        if get_tag:
            assert(self.n_cached_image == self.n_tag,
                   "inconsist tag number: {tn} and image number {imn}".format(tn=self.n_tag,imn=self.n_cached_image))
            y = self.tags[...,idx]
        else:
            y = []
        if idx is None:
            return np.reshape(self.cache_image,newshape=(self.n_cached_image,self.image_h,self.image_w,-1)),y
        else:
            return np.reshape(self.cache_image[idx,...], newshape=(len(idx), self.image_h, self.image_w, -1)),y
    def close(self):
        self.reader.close()
        javabridge.kill_vm()
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
    def n_tag(self):
        return self.tags.shape[0]


