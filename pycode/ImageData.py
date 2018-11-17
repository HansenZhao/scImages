import scipy.io as sio
import easygui
import numpy as np


class PixelCentralSet(object):
    def __init__(self,fpath = None,half_width = 30,develope_ratio = 0.1,normalization = ('median','mean')):
        if not fpath:
            fpath = easygui.fileopenbox()
        image_data = sio.loadmat(fpath)
        if len(image_data['tag'].shape) == 2:
            image_data['tag'] = image_data['tag'].reshape(image_data['tag'].shape[0],image_data['tag'].shape[1],1)
            if len(image_data['images'].shape) == 3:
                image_data['images'] = image_data['images'].reshape(image_data['images'].shape[0],
                                                                    image_data['images'].shape[1],
                                                                    image_data['images'].shape[2],1)
            elif len(image_data['images'].shape) == 2:
                image_data['images'] = image_data['images'].reshape(image_data['images'].shape[0],
                                                                    image_data['images'].shape[1],
                                                                    1, 1)
        self.raw_tag = image_data['tag'].swapaxes(0,2).swapaxes(1,2)
        # MATLAB (height,width,channel,nImage) / python (nImage,channel,height,width)
        self.raw_image = image_data['images'].swapaxes(0,3).swapaxes(1,2).swapaxes(2,3)
        # normalization: Van Valen, PLoS Comput Biol 2016, 12 (11), e1005177.
        self.normalization = normalization
        if self.normalization and self.normalization[0]:
            if self.normalization[0].startswith('median'):
                self.raw_image = self.raw_image/np.median(self.raw_image,axis=(2,3),keepdims=True)
            elif self.normalization[0].startswith('mean'):
                self.raw_image = self.raw_image / np.mean(self.raw_image, axis=(2, 3), keepdims=True)
            elif self.normalization[0].startswith('max'):
                self.raw_image = self.raw_image / np.max(self.raw_image, axis=(2, 3), keepdims=True)

        self.half_width = half_width
        self.tags = np.unique(self.raw_tag)
        self.develope_ratio = develope_ratio
        self.tag_pos_dict = dict()
        self.is_for_train_dict = dict()
        self.batch_counter_dict = dict()

        mask = np.zeros((self.raw_image.shape[0],self.raw_image.shape[2],self.raw_image.shape[3]))
        mask[:,self.half_width:-self.half_width,self.half_width:-self.half_width] = 1
        for tag in self.tags:
            self.tag_pos_dict[tag] = np.argwhere(np.logical_and(self.raw_tag == tag,mask))
            self.is_for_train_dict[tag] = np.random.rand(self.tag_pos_dict[tag].shape[0]) > self.develope_ratio
            self.batch_counter_dict[tag] = 0
        self.random_patch_pos()
    def next_set(self,size=128,batch = True,for_train = True,one_hot = False, fix_transform = None):
        if for_train and size > self.min_train_patch_num:
            raise ValueError('size arg is too large, min tag num: ' + self.min_train_patch_num)
        if not for_train and size > self.min_test_patch_num:
            raise ValueError('size arg is too large, min tag num: ' + self.min_test_patch_num)
        if size < self.n_tag:
            raise ValueError('size arg is too small, tag num: ' + str(self.n_tag))

        n_sample_pos = self.tag_sample_size(size)
        if for_train and batch and not self.check_for_valid_batch(size,for_train):
            print('batch reset')
            self.reset_batch()
            self.random_patch_pos()
        train_tag = np.zeros(shape=size,dtype=np.int32)
        train_images = np.zeros((size,self.nChannel,self.half_width*2+1,self.half_width*2+1))
        counter = 0
        positions = []
        transform_info = []
        for tag_index in range(self.n_tag):
            n_sample = n_sample_pos[tag_index]
            tag = self.tags[tag_index]
            if for_train:
                pos_pool = self.tag_pos_dict[tag][self.is_for_train_dict[tag]]
            else:
                pos_pool = self.tag_pos_dict[tag][np.logical_not(self.is_for_train_dict[tag])]
            if batch and for_train:
                start_at = self.batch_counter_dict[tag]
                pos_list = pos_pool[start_at:(start_at + n_sample), :]
                self.batch_counter_dict[tag] = start_at + n_sample
            else:
                pos_list = pos_pool[np.random.choice(range(pos_pool.shape[0]),size=n_sample,replace=False),:]
            if not fix_transform:
                transform_option = np.random.choice(range(8),size=n_sample,replace=True)
            else:
                transform_option = np.ones(shape=n_sample)*fix_transform
            #transform_option = np.random.choice(range(1), size=n_sample, replace=True)
            #transform_option = np.ones(shape=n_sample)*7
            for i in range(n_sample):
                train_tag[counter] = tag
                tmp =  PixelCentralSet.image_transform(self.raw_image[pos_list[i,0],:,
                                                       (pos_list[i,1] - self.half_width):(pos_list[i,1]+self.half_width + 1),
                                                       (pos_list[i, 2] - self.half_width):(pos_list[i, 2] + self.half_width + 1)],transform_option[i])

                if self.normalization and self.normalization[1] and self.normalization[1].startswith('mean'):
                    tmp = tmp - np.mean(tmp,axis=(1,2),keepdims=True)

                train_images[counter, :, :, :] = tmp
                positions.append(pos_list[i,:])
                transform_info.append(transform_option[i])
                counter += 1
        if one_hot:
            tmp = np.zeros(shape=(size,self.n_tag),dtype=np.int32)
            tmp[range(size),train_tag-1] = 1
            train_tag = tmp
        return train_images,train_tag,positions,transform_info
    def tag_sample_size(self,total_size):
        n_sample_pos = np.round(total_size * 1.0 / self.n_tag * np.ones(shape=(self.n_tag))).astype(np.int32)
        n_sample_pos[0] = n_sample_pos[0] + total_size - np.sum(n_sample_pos)
        return n_sample_pos
    def check_for_valid_batch(self,size,for_train):
        flag = True
        n_samples = self.tag_sample_size(size)
        for tag_index in range(self.n_tag):
            tag = self.tags[tag_index]
            if for_train:
                if n_samples[tag_index] + self.batch_counter_dict[tag] > self.patch_train_num[tag]:
                    self.batch_counter_dict[tag]=0
                    flag = False
            else:
                if n_samples[tag_index] + self.batch_counter_dict[tag] > self.patch_test_num[tag]:
                    self.batch_counter_dict[tag]=0
                    flag = False
        return flag
    def reset_batch(self):
        for tag in self.tags:
            self.batch_counter_dict[tag] = 0
        self.random_patch_pos()
    def random_patch_pos(self):
        for tag in self.tags:
            self.tag_pos_dict[tag] = self.tag_pos_dict[tag][np.random.choice(range(self.tag_pos_dict[tag].shape[0]),
                                                                             size=self.tag_pos_dict[tag].shape[0],
                                                                             replace=False), ...]
    @property
    def n_tag(self):
        return len(self.tags)
    @property
    def nChannel(self):
        return self.raw_image.shape[1]
    @property
    def nImage(self):
        return self.raw_image.shape[0]
    @property
    def image_size(self):
        return self.raw_image.shape[2:4]
    @property
    def set_size(self):
        n_row = self.raw_image.shape[2] - 2 * self.half_width
        n_col = self.raw_image.shape[3] - 2 * self.half_width
        return self.nImage * n_col * n_row
    @property
    def tag_ratio(self):
        freq_dict = dict()
        for tag in self.tags:
            freq_dict[tag] = self.tag_pos_dict[tag].shape[0]/self.set_size
        return freq_dict
    @property
    def patch_num(self):
        freq_dict = dict()
        for tag in self.tags:
            freq_dict[tag] = self.tag_pos_dict[tag].shape[0]
        return freq_dict
    @property
    def patch_train_num(self):
        freq_dict = dict()
        for tag in self.tags:
            freq_dict[tag] = self.tag_pos_dict[tag][self.is_for_train_dict[tag],...].shape[0]
        return freq_dict
    @property
    def patch_test_num(self):
        freq_dict = dict()
        for tag in self.tags:
            freq_dict[tag] = self.tag_pos_dict[tag][np.logical_not(self.is_for_train_dict[tag]),...].shape[0]
        return freq_dict
    @property
    def min_train_patch_num(self):
        arr = list(self.patch_train_num.values())
        return np.min(arr)
    @property
    def min_test_patch_num(self):
        arr = list(self.patch_test_num.values())
        return np.min(arr)
    @property
    def rarest_tag(self):
        freq = self.tag_ratio
        I = list(freq.values()).index(min(freq.values()))
        return list(freq.keys())[I]
    @staticmethod
    def image_transform(im,option):
        if option < 4:
            return np.rot90(im,k=option,axes=(2,1))
        else:
            return {
                4: lambda im: im[...,::-1],
                5: lambda im: im[...,::-1,:],
                6: lambda im: np.rot90(im,k=1,axes=(2,1))[...,::-1],
                7: lambda im: np.rot90(im,k=1,axes=(2,1))[...,::-1,:]
            }[option](im)

