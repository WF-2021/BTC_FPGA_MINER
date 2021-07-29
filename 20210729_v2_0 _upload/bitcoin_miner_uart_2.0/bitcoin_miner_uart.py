import argparse         # 命令行库
import binascii         # 二进制ASCII码
import sys              # 系统库
import socket           # TCP/IP库
import threading        # 线程库
import urllib.parse     # URL库
import serial           # 串口库
import time             # 时间库
import json             # JSON库
import hashlib          # 哈希计算库
import struct           # 数据结构库
from time import sleep  # 线程睡眠

global_extranounce2 = 0x00000001


##############################
#   各种计算函数
##############################
#   双SHA256计算
#   输入、输出是b'\x'的byte类型
def sha256d(message):
    return hashlib.sha256(hashlib.sha256(message).digest()).digest()


#   byte大小端转换
#   输入是16进制str类型，输出是b'\x'的byte类型
#   例如：'12345678' -> b'\x78\x56\x34\x12'
def swap_endian_word(hex_word):
    #   将16进制字符串类型转为b'\x'的byte类型
    message = binascii.unhexlify(hex_word)

    #   判断是否是4字节的word
    if len(message) != 4:
        raise ValueError('必须是4字节的word！')

    #   大小端转换，byte的排列顺序颠倒
    return message[::-1]


#   word中byte的大小端转换，返回的是b'\x'的byte类型
#   输入是16进制str类型，输出是b'\x'的byte类型
#   例如：'1122334455667788' -> b'\x44\x33\x22\x11\x88\x77\x66\x55'
def swap_endian_words(hex_words):
    #   将16进制字符串类型转为b'\x'的byte类型
    message = binascii.unhexlify(hex_words)

    #   判断word中的字节数是否是4的整数倍
    if len(message) % 4 != 0:
        raise ValueError('必须是4字节对齐的word！')

    #   以4个byte为一个word，大小端转换
    tmp = b''
    for i in range(0, len(message) // 4):
        tmp = tmp + message[4 * i: 4 * i + 4][::-1]
    return tmp


#   根据矿池给的针对本矿机的难度，计算本次挖矿的目标值
#   difficulty是int型的，可以直接用于计算
def set_target(difficulty):
    #   计算本次挖矿的目标值
    #   目标（256bit）=创世块目标（0x1d00ffff） / difficulty
    #   源码中把计算出的目标值扩大了一点，这样就降低了挖矿的难度
    #   同时考虑了难度如果是0无法做除法的情况
    if difficulty == 0:
        target = 2 ** 256 - 1
    else:
        #   第一行是原始工程的算法，第二行是我认为更加准确且简单的算法
        target = int(((2 ** (256 - 32)) - 1) / difficulty)

    #   将原本target的位宽定位256bit，高位补零，右对齐
    #   self._target是十六进制str类型，即target十六进制数直接表示
    target = '%064x' % target

    #   打印当前目标和难度，并返回
    print("当前难度为：", difficulty)
    print("当前挖矿目标为：", target)
    return target


#   Mining_Machine类
#   实现挖矿的各种功能
class MiningMachine(object):
    #   Mining类的初始化函数
    def __init__(self, url, username, password, com, baudrate):
        #   TCP
        self._tcp = None                            # TCP
        self._tcp_url = url                         # TCP 矿池的URL
        self._tcp_username = username               # TCP 用户名
        self._tcp_password = password               # TCP 密码
        self._tcp_rx_thread = None                  # TCP 接收线程
        self._tcp_lock = threading.RLock()          # TCP 线程重锁，线程同步和重复锁定
        self._tcp_message_id = 1                    # TCP 消息编号
        self._tcp_requests = dict()                 # TCP 发送请求的记录
        self._tcp_login = 0                         # TCP 登录成功标志
        self._tcp_login_first_job = 0               # TCP 登录成功后的第一个任务标志
        self._tcp_change_difficulty_first_job = 0   # TCP 修改难度后的第一个任务标志

        #   UART
        self._uart = None                       # UART
        self._uart_com = com                    # UART COM口
        self._uart_baudrate = baudrate          # UART 波特率
        self._uart_rx_thread = None             # UART 接收线程

        #   MINING
        self._mining_target = None              # MINING 挖矿目标，str类型
        self._mining_job_id = None              # MINING job_id，str类型
        self._mining_prevhash = None            # MINING prevhash，str类型，256nit
        self._mining_coinb1 = None              # MINING coinb1，str类型
        self._mining_coinb2 = None              # MINING coinb2，str类型
        self._mining_merkle_branches = None     # MINING merkle_branches，list类型，每个单元是str类型
        self._mining_version = None             # MINING version，str类型
        self._mining_nbits = None               # MINING nbits，str类型
        self._mining_ntime = None               # MINING ntime，str类型
        self._mining_clean_jobs = None          # MINING clean_jobs，bool类型
        self._mining_extranounce1 = None        # MINING extranounce1，str类型
        self._mining_extranounce2_size = None   # MINING extranounce2_size，int类型
        self._mining_worker_name = None         # MINING 用户名，str类型
        self._mining_accepted_shares = 0        # MINING 接收成功计数，int类型

    #   Mining_Machine异常类，用于后续操作错误时，手动抛出异常
    class MiningMachineException(Exception):
        pass

    ##############################
    #   串口部分
    ##############################
    #   给FPGA发送命令
    def uart_send(self, command_bin, data_bin, extranounce2_bin, target_bin):
        self._uart.write(command_bin + data_bin + extranounce2_bin + target_bin)

    #   _uart_rx_handle线程的运行函数
    #   用于处理FPGA发回的数据
    def _uart_rx_handle(self):
        global global_extranounce2

        while True:
            #   等待串口中接收了9个byte的数据，就可以开始读了
            if self._uart.inWaiting() >= 9:
                cmd = self._uart.read(1)
                nounce = self._uart.read(4)
                extranounce2 = self._uart.read(4)

                #   接收到有效挖矿数据
                if cmd == b'\x01':
                    print("接收到FPGA的有效挖矿数据")
                    params = [self._mining_worker_name] + [self._mining_job_id, extranounce2.hex(), self._mining_ntime, nounce.hex()]
                    self.tcp_send(method='mining.submit', params=params)

                #   接收到挖矿空间已满信息
                elif cmd == b'\x02':
                    print("接收到FPGA的挖矿空间已满")
                    self.hash_prefix_calc()

                #   接收到挖矿空间已满信息，且有效挖矿数据
                elif cmd == b'\x03':
                    print("接收到FPGA的挖矿空间已满信息，且有效挖矿数据")
                    params = [self._mining_worker_name] + [self._mining_job_id, extranounce2.hex(), self._mining_ntime, nounce.hex()]
                    self.tcp_send(method='mining.submit', params=params)
                    self.hash_prefix_calc()

                #   其他情况报错
                else:
                    print("接收到FPGA的信息错误")
                sleep(0.05)

    ##############################
    #   网络部分
    ##############################
    #   给矿池发送命令
    def tcp_send(self, method, params):
        #   如果没有网络连接，则手动抛出异常
        if not self._tcp:
            raise self.MiningMachineException("没有网络连接")

        #   创建了一个request字典
        request = dict(id=self._tcp_message_id, method=method, params=params)

        #   将request进行JSON格式转换
        #   socket.send发送的是byte型的数据，所以需要把str型的message进行转换
        #   转换的时候是将message中的字符串，按照ascii码转成对应的byte数据
        #   68656c6c6f20776f7264 -> b'68656c6c6f20776f7264' = b'\x36\x38\x36\x35\x36...'
        message = json.dumps(request)
        with self._tcp_lock:
            self._tcp_requests[self._tcp_message_id] = request
            self._tcp_message_id += 1
            self._tcp.send((message + '\n').encode())

        #   打印发送信息 {"id": 1, "method": "mining.subscribe", "params": []}
        # print(message)

        #   返回发送的内容，方便后续处理矿池发回的消息
        return request

    #   _tcp_rx_handle线程的运行函数
    #   用于处理矿池发回的数据
    def _tcp_rx_handle(self):
        #   接收的数据
        data = ""

        while True:
            #   判断是否接受完成
            #   如果接受完成，则从'\n'分割，共分成2部分
            if '\n' in data:
                (line, data) = data.split('\n', 1)
            #   如果未接收完成，则从self._socket中继续接收，并将接收的数据拼接
            #   socket.recv接收的数据是byte型的，所以需要转成str型赋值给chunk
            #   转换的时候是将chunk的byte数据，按照ascii码转成对应的字符串
            #   b'68656c6c6f20776f7264' = b'\x36\x38\x36\x35\x36...' -> 68656c6c6f20776f7264
            else:
                chunk = self._tcp.recv(1024)
                data += chunk.decode()
                continue

            #   解析JSON格式的数据，如果解析失败则打印消息
            try:
                reply = json.loads(line)
                # print(reply)
            except IOError:
                print("将TCP数据解析成JSON格式失败！")
                continue

            #   判断返回信息是否与请求信息对应，如果对应则处理返回信息
            try:
                request = None
                with self._tcp_lock:
                    # 如果返回的reply中还有请求时的id，则处理则使用handle_reply处理
                    if 'id' in reply and reply['id'] in self._tcp_requests:
                        request = self._tcp_requests[reply['id']]
                    self.tcp_handle_reply(request=request, reply=reply)
            except IOError:
                print("返回消息与请求消息内容不符！")
                continue

    #   处理回复信息函数
    #   根据返回信息中的方法，分别进行处理
    def tcp_handle_reply(self, request, reply):
        global global_extranounce2

        #   返回信息的方法为'mining.set_difficulty'，则处理“改变难度，计算目标”
        if reply.get('method') == 'mining.set_difficulty':
            #   如果返回的信息结构不对，则挂起
            if 'params' not in reply or len(reply['params']) != 1:
                raise self.MiningMachineException("矿池回复的改变难度格式错误！")

            #   提取矿池返回的参数
            #   difficulty，int类型
            (difficulty,) = reply['params']

            #   根据难度值计算目标值，并将目标值给到Subscription类中
            self._mining_target = set_target(difficulty)

            #   清空改变难度后第一个任务的标志
            self._tcp_change_difficulty_first_job = 0

            #   成功完成改变难度，计算目标
            print('成功完成改变难度，计算目标任务!')

        #   返回信息的方法为'mining.notify'，则处理“挖矿任务”
        elif reply.get('method') == 'mining.notify':
            #   如果返回的信息结构不对，则挂起
            if 'params' not in reply or len(reply['params']) != 9:
                raise self.MiningMachineException("矿池回复的挖矿任务格式错误！")

            #   提取矿池返回的参数
            (self._mining_job_id,
             self._mining_prevhash,
             self._mining_coinb1,
             self._mining_coinb2,
             self._mining_merkle_branches,
             self._mining_version,
             self._mining_nbits,
             self._mining_ntime,
             self._mining_clean_jobs) = reply['params']

            #   只有在登录后的第一个任务，或者更改难度后的第一个任务，或者强制开始新的任务时，调用挖矿线程
            if self._tcp_login == 1 and self._tcp_login_first_job == 0:
                global_extranounce2 = 1
                self.hash_prefix_calc()

                #   第一个任务或新任务标志，置位
                self._tcp_login_first_job = 1
                self._tcp_change_difficulty_first_job = 1

                #   登录后的第一个任务，开启挖矿线程
                print('登录后的第一个任务，开启挖矿!')

            elif self._tcp_login == 1 and self._tcp_change_difficulty_first_job == 0:
                global_extranounce2 = 1
                self.hash_prefix_calc()

                #   第一个任务或新任务标志，置位
                self._tcp_login_first_job = 1
                self._tcp_change_difficulty_first_job = 1

                #   改变难度后的第一个任务，开启挖矿线程
                print('改变难度后的第一个任务，开启挖矿!')

            elif self._tcp_login == 1 and self._mining_clean_jobs:
                global_extranounce2 = 1
                self.hash_prefix_calc()

                #   第一个任务或新任务标志，置位
                self._tcp_login_first_job = 1
                self._tcp_change_difficulty_first_job = 1

                #   强制开始新的任务，开启挖矿线程
                print('强制开始新的任务，开启挖矿!')

        #   如果还未登录，下面的是因为矿池在返回信息的时候不返回方法，所以只能从发送请求的方法中判断
        elif request:
            #   请求信息的方法为'mining.subscribe'，则处理“订阅任务”
            if request.get('method') == 'mining.subscribe':
                #   如果返回的信息结构不对，则挂起
                if 'result' not in reply or len(reply['result']) != 3 or len(reply['result'][0]) != 2:
                    raise self.MiningMachineException("矿池回复的订阅任务格式错误！")

                #   提取矿池返回的参数
                #   mining_notify，list类型。一般为['mining.notify', '数字']，都是str类型
                #   subscription_id，list类型。一般为['mining.set_difficulty', '数字']，都是str类型
                ((mining_notify, mining_difficulty), self._mining_extranounce1, self._mining_extranounce2_size) = reply['result']

                #   成功完成订阅任务
                print('成功完成订阅任务!')

                #   发送“矿机登录”请求
                self.tcp_send(method='mining.authorize', params=[self._tcp_username, self._tcp_password])

            #   请求信息的方法为'mining.authorize'，则处理“账户登录”
            elif request.get('method') == 'mining.authorize':
                #   如果返回的信息结构错误，或者拒绝了账户登录，则挂起
                if 'result' not in reply or not reply['result']:
                    print('矿池拒绝了账户登录！')

                #   将用户名从请求信息中提取出来，因为在账户登录时，矿池不会返回用户名
                #   用户名，str类型
                self._mining_worker_name = request['params'][0]

                #   登录成功，清空改变难度后第一个任务的标志
                self._tcp_login = 1
                self._tcp_login_first_job = 0

                #   成功完成账户登录任务
                print('成功完成账户登录任务!')

            #   请求信息的方法为'mining.submit'，则处理“提交结果”
            elif request.get('method') == 'mining.submit':
                #   如果返回的信息结构错误，或者拒绝了提交结果，则挂起
                if 'result' not in reply or not reply['result']:
                    print('矿池拒绝了提交结果！')
                    print(reply)

                else:
                    #   本次挖矿被接收的结果计数，加一
                    self._mining_accepted_shares += 1
                    #   成功完成一次提交结果
                    print('成功完成一次提交结果! 本次挖矿共提交次数：', self._mining_accepted_shares)

    #   挖矿，整个挖矿的计算过程
    #   nounce_start，nounce的起始值
    #   nounce_stride，nounce的步进值，方便在多线程中使用
    def hash_prefix_calc(self):
        global global_extranounce2

        #   将extranounce2以无符号整形分成字节端元，并大端排列，'>I'是无符号整形大端排列的意思
        #   extranounce2是挖矿空间，所以无所谓大小端排列，都是可以的。在提交结果时也无需对extranounce2做大小端转换
        #   例如extranounce2(int类型)=1，那么extranounce2_bin(b'\x'的byte类型)=b'\x00\x00\x00\x01'
        extranounce2_bin = struct.pack('>I', global_extranounce2)
        print('extranounce2_bin = ', extranounce2_bin.hex())

        #   构造coinbase_bin(b'\x'的byte类型)信息，{coinb1(16进制str类型)， extranounce1(16进制str类型)， extranounce2_bin(b'\x'的byte类型) ， coinb2(16进制str类型)}
        #   binascii.unhexlify()是把16进制str类型转换为b'\x'的byte类型，所以'68'转换为b'\x68'
        coinbase_bin = binascii.unhexlify(self._mining_coinb1) + binascii.unhexlify(self._mining_extranounce1) + extranounce2_bin + binascii.unhexlify(self._mining_coinb2)
        coinbase_hash_bin = sha256d(coinbase_bin)

        #   coinbase与merkle_branch（交易列表）两两配对成512bit数据，计算双sha256，得到默克尔根(b'\x'的byte类型)
        merkle_root_bin = coinbase_hash_bin
        for branch in self._mining_merkle_branches:
            merkle_root_bin = sha256d(merkle_root_bin + binascii.unhexlify(branch))

        #   构建区块头，b'\x'的byte类型，{version, prevhash, merkle_root_bin, ntime, nbits}
        #   注意，从矿池得到的这几个数据是需要进行大小端转换的
        header_prefix_bin = swap_endian_word(self._mining_version) + swap_endian_words(self._mining_prevhash) + merkle_root_bin + swap_endian_word(self._mining_ntime) + swap_endian_word(self._mining_nbits)
        print('header_prefix_bin = ', header_prefix_bin.hex())

        #   串口发送FPGA挖矿所需所有数据
        self.uart_send(b'\x01', header_prefix_bin, extranounce2_bin, binascii.unhexlify(self._mining_target))

        #   extranounce2递增
        global_extranounce2 += 1

    ##############################
    #   网络和串口部分
    ##############################
    #   在这个函数中循环挖矿
    def mining_forever(self):
        ##############################
        #   与FPGA进行连接
        ##############################
        #   创建用于FPGA通信的uart，并连接
        self._uart = serial.Serial(self._uart_com, self._uart_baudrate)

        #   如果已经存在_tcp_rx_thread线程，则手动抛出异常
        if self._uart_rx_thread:
            raise self.MiningMachineException("FPGA已被连接！")

        #   创建一个_uart_rx_thread线程，并开启
        #   这个线程执行的是“_uart_rx_handle函数”
        self._uart_rx_thread = threading.Thread(target=self._uart_rx_handle)
        self._uart_rx_thread.daemon = True
        self._uart_rx_thread.start()

        ##############################
        #   与矿池进行连接
        ##############################
        #   根据矿池的URL，解析出对应的IP地址和端口
        tcp_url = urllib.parse.urlparse(self._tcp_url)

        #   创建用于TCP/IP通信的socket，并连接
        self._tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._tcp.connect((tcp_url.hostname, tcp_url.port))

        #   如果已经存在_tcp_rx_thread线程，则手动抛出异常
        if self._tcp_rx_thread:
            raise self.MiningMachineException("矿池已被连接！")

        #   创建一个_tcp_rx_thread线程，并开启
        #   这个线程执行的是“_tcp_rx_handle函数”
        self._tcp_rx_thread = threading.Thread(target=self._tcp_rx_handle)
        self._tcp_rx_thread.daemon = True
        self._tcp_rx_thread.start()

        #   发送挖矿作业请求
        self.tcp_send(method='mining.subscribe', params=[])

        #   一直循环挖矿
        while True:
            time.sleep(10)


#   主函数
if __name__ == '__main__':
    #   创建一个命令行解析器
    #   description是对这个命令行解析器的描述
    parser = argparse.ArgumentParser(description="比特币矿机")

    #   添加命令行交互参数
    #   '-xx'是命令行的命令名称
    #   dest是执行这条输入参数命令后，这个参数的名字，在后续解析中会使用该名字
    #   default是输入参数的默认值
    #   help是对这条命令的文字说明
    parser.add_argument('-url', dest='url', default='', help='miner pool url(eg: stratum+tcp://foobar.com:3333)')  # 矿池URL
    parser.add_argument('-user', dest='username', default='', help='username for mining server')                   # 用户名
    parser.add_argument('-pass', dest='password', default='', help='password for mining server')                   # 密码
    parser.add_argument('-com', dest='uart_com', default='', help='com for uart')                                  # 串口COM号
    parser.add_argument('-baudrate', dest='uart_baudrate', default='', help='baudrate for uart')                   # 串口波特率

    #   解析命令行输入参数
    #   sys.argv[1:]是指将所用输入的命令都解析
    options = parser.parse_args(sys.argv[1:])
    print(options.url, options.username, options.password)

    #   如果输入了矿池的URL，则开始挖矿
    if options.url:
        mining_machine = MiningMachine(options.url, options.username, options.password, options.uart_com, options.uart_baudrate)
        mining_machine.mining_forever()
