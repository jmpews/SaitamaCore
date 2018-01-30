## Prologue

**Saitama aka 琦玉老师**

在阅读 <x86汇编语言: 从实模式到保护模式>, <操作系统-清华大学>, <操作系统真相还原> 构造了一个 kernel.

两本书/视频, 都是非常好的教材. <x86汇编语言: 从实模式到保护模式> 更偏向基础, <操作系统-清华大学> 更偏向基础和实用的结合, <操作系统真相还原> 是非常非常好的一本书, 讲的非常详细.

## Kernel 处理流程

#### bootloader 处理

BIOS 仅仅从磁盘中加载 1st sector 到 0x7c00, 在这 512 bytes 要做下面三个基本操作.

* 从实模式切换保护模式, 建立基础的GDT并填充段描述符(segment descripter)
* 加载具体 kernel
* 跳转到 kernel 初始化入口点, 把控制权交给 kernel systerm.

#### Kernel 的初始化

* 重建GDT, 开启分段机制
* 开启分页机制
 

## Kernel 设计规则

#### 0x0 寄存器使用规定

```
eax : 累加寄存器, 随意使用
ebx: 基寄存器, 通常用作段内偏移
ecx: 计数器
edx: 数据暂存寄存器

edi: 目的地址索引
esi: 源地址索引
```
#### 0x1 Procedure Call Standard(函数调用规约)

在 MBR 的 bootloader 期间:
`ax,  bx, cx` 分别作为参数寄存器, 不够采用栈传递参数, 返回值放在 `ax`.

进入 Kernel 后:

* 采用栈做参数传递, caller 负责平衡栈.
* 对于结构体采用栈分配空间作为隐藏的第一个参数传递给 callee
