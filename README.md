# NARS-Embodied-Interface NARS具身接口

![GitHub License](https://img.shields.io/github/license/ARCJ137442/JuNEI?style=for-the-badge&color=a270ba)
![Code Size](https://img.shields.io/github/languages/code-size/ARCJ137442/JuNEI?style=for-the-badge&color=a270ba)
![Lines of Code](https://www.aschey.tech/tokei/github.com/ARCJ137442/JuNEI?style=for-the-badge&color=a270ba)
[![Language](https://img.shields.io/badge/language-Julia-purple?style=for-the-badge&color=a270ba)](https://cn.julialang.org/)

开发状态：

![Created At](https://img.shields.io/github/created-at/ARCJ137442/JuNEI?style=for-the-badge)
![Last Commit](https://img.shields.io/github/last-commit/ARCJ137442/JuNEI?style=for-the-badge)

[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-2.0.0-%23FE5196?style=for-the-badge)](https://conventionalcommits.org)

## 简介

## Introduction 简介

一个以 ***NARS*** 作为AI玩家，提供集成访问&调用的接口

- 缩写：NEI
- 原型：[ARCJ137442/NARS-FighterPlane](https://github.com/ARCJ137442/NARS-FighterPlane) v2.i_alpha
- Python版本(移植来源，现无暇维护)：[ARCJ137442/NARS-PyNEI](https://github.com/ARCJ137442/PyNEI)

## Author's Note 作者注

- 本实现作为从PyNEI迁移过来的版本，在功能上与PyNEI并无太大差异，但代码组织上更清晰，且能更好地支持各大接口特性。
- 因作者目前（2023-10-26）的工作重点转移到了「AI虚拟环境」上，所以该接口的定位发生了变化：
  - 「接口」部分：整体退居幕后
    - 目前以「服务器」的形式被使用，用于**对接用其它语言编写的虚拟环境**
    - 代码体现：如`Console`类型的`launch!`方法
    - 🚩未来将对「跨CIN指令输入」使用[**NAVM**](https://github.com/ARCJ137442/NAVM.jl)
  - 「具身」部分**暂停维护**：
    - 核心转移为「通信」上（体现同上）
  - 「NAL」部分**拆分外包**：
    - 与Narsese直接相关的，交给[**JuNarsese**](https://github.com/ARCJ137442/JuNarsese.jl)与[**JuNarseseParsers**](https://github.com/ARCJ137442/JuNarseseParsers.jl)
  - 外部的「游戏」部分**停止更新**：单一的呈现环境（命令行）已无法满足调试需要
- ❓目前 *executables* 目录下的可执行文件似乎需要外置为Artifacts

## Concept 概念

- NARS: Non-Axiomatic Reasoning System | 非公理推理系统
- NAL: Non-Axiomatic Logic | 非公理逻辑
- CIN: Computer Implementation of NARS  | NARS的计算机实现

## Preparation 预备

1. [Julia](https://julialang.org/) 1.9.1+

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

## Quick Start 快速开始

### 启动终端

要通过JuNEI启动（任意一个CIN）终端，可以通过「控制台」`Console`进行相关启动

📌启动代码已内置到了`test_console.jl`中，在系统安装有`Julia`的情况下，可以通过以下命令启动

```bash
cd 【JuNEI文件夹根目录】
julia test/test_console.jl
```

在启动过程中，脚本会提示输入CIN类型（OpenNARS/ONA/NARS-Python/...），只需选择一个即可

⚠️注意：某些CIN有**额外环境要求**

- OpenNARS（`opennars.jar`）：需要**Java运行时**（[Oracle官网下载](https://www.oracle.com/java/technologies/downloads/)）
- ONA（`NAR.exe`）：需要**Cygwin**（[中文官网下载](http://www.cygwin.cn/site/install/)）

### 快速启动OpenNARS Websocket服务器

要启动OpenNARS Websocket服务器，只需在[启动终端](#启动终端)的基础上，**将其中的`test_console.jl`换成`test_console_OpenNARS.jl`即可**

## References 参考

NARS计算机实现

- OpenNARS: <https://github.com/opennars/opennars>
- ONA: <https://github.com/opennars/OpenNARS-for-Applications>
- NARS-Python: <https://github.com/ccrock4t/NARS-Python>
- OpenJunars: <https://github.com/AIxer/OpenJunars>

NARS+ & 游戏Demo

- NARS-Pong in Unity3D: <https://github.com/ccrock4t/NARS-Pong>
- NARS-FighterPlane by BoYang Xu: <https://github.com/Noctis-Xu/NARS-FighterPlane>
- ARCJ137442/NARS-FighterPlane: <https://github.com/ARCJ137442/NARS-FighterPlane>
