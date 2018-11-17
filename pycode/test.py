import ImageData
import tfmodel
import tensorflow as tf
from tensorflow.examples.tutorials.mnist import input_data
from tensorflow.keras.datasets import mnist
import numpy as np


a = ImageData.PixelCentralSet(fpath='J:\\CNN-Cell-profile-XRZhang\\code\\spatial_conti_real.mat',half_width=2,normalization=('max',None))
im,tag,pos,t = a.next_set(10)
'''
def random_batches(X,y,batch_size,num):
    batches = []
    for i in range(num):
        idx = np.random.randint(X.shape[0],size=batch_size)
        batches.append((X[idx],y[idx]))
    return batches

(X_train,y_train),(X_test,y_test) = mnist.load_data()


TRAIN_SET_SIZE = X_train.shape[0]
TEST_SET_SIZE = X_test.shape[0]
IMAGE_SIZE = X_train.shape[1]

X_train = np.reshape(X_train,[TRAIN_SET_SIZE,IMAGE_SIZE,IMAGE_SIZE,1])
X_test = np.reshape(X_test,[TEST_SET_SIZE,IMAGE_SIZE,IMAGE_SIZE,1])

INPUT_CHANNEL = 1
BATCH_SIZE = 512
LEARN_RATE = 0.01
LEARN_RATE_DECAY = 0.99
TRAINING_STEPS = 30000
KEEP_PROB = 1.0
MODEL_NAME = '/save/Model/model.ckpt'
SUMMARY_NAME = '/save/Summary/'

lenet_model = tfmodel.GeneralNet(('conv5-6','relu','pool','conv5-16','relu','pool',
                                  'flat','dense120','relu','dense84','relu','dense10'))

X = tf.placeholder(tf.float32, shape=[BATCH_SIZE, IMAGE_SIZE, IMAGE_SIZE, INPUT_CHANNEL])
y = tf.placeholder(tf.int32, shape=[BATCH_SIZE])

y_est,net = lenet_model.inference(X)

cross_entropy = tf.nn.sparse_softmax_cross_entropy_with_logits(logits=y_est,labels=y)
cross_entropy_mean = tf.reduce_mean(cross_entropy)

accuracy = tf.reduce_mean(tf.cast(tf.equal(tf.argmax(y_est,1),tf.cast(y,tf.int64)),tf.float32))

train_step = tf.train.AdamOptimizer(LEARN_RATE).minimize(cross_entropy_mean)

saver = tf.train.Saver()

with tf.Session() as sess:
    writer = tf.summary.FileWriter(SUMMARY_NAME,sess.graph)
    tf.global_variables_initializer().run()
    num_batch = int(np.floor(X_train.shape[0]/BATCH_SIZE))
    for epoch in range(TRAINING_STEPS):
        for batch in range(num_batch):
            offset = BATCH_SIZE*batch
            (xs, ys) = (X_train[(0+offset):(BATCH_SIZE+offset),...],
                        y_train[(0+offset):(BATCH_SIZE+offset),...])
            _, cost, accu = sess.run([train_step, cross_entropy_mean, accuracy], feed_dict={X: xs, y: ys})
        minibatches = random_batches(X_test, y_test, BATCH_SIZE, 1)
        (xs, ys) = minibatches[0]
        _, cost, accu = sess.run([train_step, cross_entropy_mean, accuracy], feed_dict={X: xs, y: ys})
        print('Cost after %d epoch: %f, test accuracy: %f' % (epoch, cost, accu))

        minibatches = random_batches(X_train, y_train, BATCH_SIZE, 1)
        (xs, ys) = minibatches[0]
        accu = sess.run(accuracy, feed_dict={X: xs, y: ys})
        print('train accuracy: %f' % (accu))
        saver.save(sess, MODEL_NAME)

writer.close()
'''