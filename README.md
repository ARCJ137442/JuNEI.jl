# NARS-Embodied-Interface NARS具身接口

一个以 ***NARS*** 作为AI玩家，提供集成访问&调用的接口

- 缩写：NEI
- 原型：[ARCJ137442/NARS-FighterPlane](https://github.com/ARCJ137442/NARS-FighterPlane) v2.i_alpha
- Python版本(移植来源，现无暇维护)：[ARCJ137442/NARS-PyNEI](https://github.com/ARCJ137442/PyNEI)

## Concept 概念

- NARS: Non-Axiomatic Reasoning System | 非公理推理系统
- NAL: Non-Axiomatic Logic | 非公理逻辑
- CIN: Computer Implementation of NARS  | NARS的计算机实现

## Preparation 预备

1. Julia 1.9.1+

## Feature 特性

- 对接多个NARS计算机实现(CIN)，实现「多实现，一窗口」
  - 可在一个终端里选择多个CIN进行交互
- 更通用化的具身接口代码，帮助更快对接游戏与NARS
  - 将「智能体定义」和「与NARS程序通信」分离
  - 集中定义NAL语句和元素，避免分散与重复
  - 更高的代码组织效率
- 异步CIN管理机制
  - 对使用exe shell交互的CIN：
    - 一个子进程启动CIN实例
    - 即时异步操作写入输入
    - 一个异步循环读取输出
  - 对使用Julia/Python模块交互的CIN：
    - 异步导入所用模块
    - 通过专门的「接口代码文件」调用模块类型&方法

## Author's Note 作者注

## References 参考

NARS计算机实现

- OpenNARS: <https://github.com/opennars/opennars>
- ONA: <https://github.com/opennars/OpenNARS-for-Applications>
- NARS-Python: <https://github.com/ccrock4t/NARS-Python>
- OpenJunars: <https://github.com/AIxer/OpenJunars>

NARS+ & 游戏Domo

- NARS-Pong in Unity3D: <https://github.com/ccrock4t/NARS-Pong>
- NARS-FighterPlane by Boyang Xu: <https://github.com/Noctis-Xu/NARS-FighterPlane>
- ARCJ137442/NARS-FighterPlane: <https://github.com/ARCJ137442/NARS-FighterPlane>
