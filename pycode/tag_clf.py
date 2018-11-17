import ImageData
import tensorflow as tf
import tfmodel
import numpy as np
import hsutils
import time

def preproc_im(im,pos):
    tmp = im.swapaxes(1,3)
    r = np.random.choice(np.unique(im),size=(im.shape[0],1))
    tmp[:,pos,pos,:] = r
    return tmp

def train(cons_str,data_path,half_width,model_name,batch_size = 1024,lr=0.0001,keep_prob = 1.0, decay=None, max_iter = 30000,queue_length=20,save_path = '/save'):
    data_set = ImageData.PixelCentralSet(fpath=data_path,half_width=half_width,normalization=('max',None))
    n_batch = np.int32(np.floor(data_set.min_train_patch_num / batch_size))
    print('minibatch number: %d' %(n_batch))
    model = tfmodel.GeneralNet(construct_str=cons_str)

    para = hsutils.parameters_record(model_name=model_name,cons_str=cons_str,half_width=half_width,batch_size=batch_size,
                                     learn_rate=lr,learn_rate_decay=decay,keep_prob=keep_prob,max_iter=max_iter,
                                     queue_length=queue_length,save_path=save_path)
    para.write_config(model_name+'.txt',save_path+'/'+model_name+'/config')

    X = tf.placeholder(tf.float32,shape=[batch_size,2*half_width+1,2*half_width+1,data_set.nChannel],name='X')
    y = tf.placeholder(tf.int32,shape=[batch_size],name='y')
    kp = tf.placeholder(tf.float32,name='keep_prob')

    lt = tf.placeholder(tf.float32,name='loss_trend')
    loss_trend = hsutils.fix_size_queue(queue_length,1)
    loss_last = np.inf
    tf.summary.scalar('loss trend',lt,collections=['train'])

    if decay:
        global_step = tf.Variable(0,trainable=False)
        learn_rate = tf.train.exponential_decay(lr,global_step=global_step,decay_steps=n_batch,decay_rate=decay,staircase=True,name='learning_rate')
        tf.summary.scalar('learning rate',learn_rate,collections=['train'])

    y_est,net = model.inference(X,keep_prob=kp)

    cross_entropy = tf.reduce_sum(tf.nn.sparse_softmax_cross_entropy_with_logits(logits=y_est,labels=y))
    pred = tf.argmax(y_est,1)
    accuracy = tf.reduce_mean(tf.cast(tf.equal(y,tf.cast(pred,tf.int32)),tf.float32))
    tf.summary.scalar('loss', cross_entropy, collections=['train'])
    tf.summary.scalar('accuracy', accuracy, collections=['train', 'test'])
    tf.summary.histogram('prediction',pred,collections=['test'])

    if decay:
        train_op = tf.train.AdamOptimizer(learn_rate).minimize(cross_entropy,global_step=global_step)
    else:
        train_op = tf.train.AdamOptimizer(lr).minimize(cross_entropy)

    saver = tf.train.Saver()
    train_data_fetch = tf.summary.merge_all('train')
    test_data_fetch = tf.summary.merge_all('test')

    with tf.Session() as sess:
        train_writer = tf.summary.FileWriter(save_path+ '/' + model_name + '/summary/train/',sess.graph)
        test_writer = tf.summary.FileWriter(save_path + '/' + model_name + '/summary/test/', sess.graph)
        tf.global_variables_initializer().run()
        tf.local_variables_initializer().run()
        for epoch in range(max_iter):
            start_time = time.time()
            for i in range(n_batch):
                xs,ys,_,_ = data_set.next_set(size=batch_size)
                sess.run(train_op,feed_dict={X:preproc_im(xs,half_width),y:ys,kp:keep_prob})
            data_set.reset_batch()

            xs, ys, _, _ = data_set.next_set(size=batch_size,for_train=True,batch=False)
            train_cost, train_accu, summ = sess.run([cross_entropy, accuracy, train_data_fetch],
                                                    feed_dict={X: preproc_im(xs,half_width), y: ys,kp:1.0,lt:loss_trend.mean()})
            if train_cost < loss_last:
                loss_trend.push(1)
            else:
                loss_trend.push(-1)
            loss_last = train_cost

            print('After: %d epoch, train cost: %.3f, train accuracy: %.3f, trend: %.2f' %(epoch,train_cost,train_accu,loss_trend.mean()))
            train_writer.add_summary(summ,epoch)

            xs, ys, _, _ = data_set.next_set(size=batch_size, for_train=False, batch=False)
            test_cost, test_accu, summ = sess.run([cross_entropy, accuracy, test_data_fetch], feed_dict={X: preproc_im(xs,half_width), y: ys, kp:1.0})
            print('testcost: %.3f, test accuracy: %.3f' % (test_cost, test_accu))
            test_writer.add_summary(summ, epoch)
            saver.save(sess,save_path + '/' + model_name + '/model/',global_step=epoch)
            duration = time.time()-start_time
            print('loop duration: %d min, %d secon,estimate remian %d hour, %d min'
                  %(int(duration/60),duration%60,duration*(max_iter-1-epoch)/3600,int(((duration*(max_iter-1-epoch))%3600)/60)))

#
train(('conv5-6','relu','pool','conv5-16','relu','pool','flat','dense120','relu','dense84','relu','dense3'),
     'J:\\CNN-Cell-profile-XRZhang\\code\\spatial_conti_real.mat',30,'SpaContiLeNet5-1',max_iter=1000)
tf.reset_default_graph()
train(('conv5-6','relu','pool','conv5-16','relu','pool','flat','dense120','relu','dense84','relu','dense3'),
     'J:\\CNN-Cell-profile-XRZhang\\code\\spatial_conti_real.mat',50,'SpaContiLeNet5-2',max_iter=1000)
tf.reset_default_graph()
train(('conv7-8','relu','pool','sconv3-16','relu','sconv3-16','relu','pool','sconv3-32','relu','sconv3-32','relu',
       'flat','dense120','relu','dense84','relu','dense3'),
     'J:\\CNN-Cell-profile-XRZhang\\code\\spatial_conti_real.mat',50,'SpaContiLeNet5-3',max_iter=2000)
# tf.reset_default_graph()
# train(('conv5-6','relu','pool','conv5-16','relu','pool','flat','dense120','relu','dense84','relu','dense3'),
#      'J:\\CNN-Cell-profile-XRZhang\\code\\test.mat',30,'LeNet5-2',decay=0.95,max_iter=1)
# tf.reset_default_graph()
# train(('conv5-6','relu','pool','conv5-16','relu','pool','flat','dense120','relu','dense84','relu','dense3'),
#      'J:\\CNN-Cell-profile-XRZhang\\code\\test.mat',30,'LeNet5-3',decay=0.99,max_iter=200)
# tf.reset_default_graph()
# train(('conv5-6','relu','pool','conv5-16','relu','pool','flat','dense120','relu','dense84','relu','dense3'),
#      'J:\\CNN-Cell-profile-XRZhang\\code\\test.mat',30,'LeNet5-4',decay=0.995,max_iter=200)
# para = hsutils.parameters_record(cons_str=('a','b'),half_width=1.0,decay=None,max_iter=3)
# para.write_config('test.txt')



