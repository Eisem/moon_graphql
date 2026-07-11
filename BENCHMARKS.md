# 性能基准

本项目使用 MoonBit 官方 `moon bench` 与 `moonbitlang/core/bench`，对相同的内存输入重复测量，避免把文件 I/O、终端输出或 Schema 初始化时间混入单阶段结果。

## 场景

| 名称 | 输入 | 测量范围 |
| --- | --- | --- |
| parse-10 | 10 个带嵌套选择集的顶层字段 | Lexer + Parser + AST 构建 |
| parse-100 | 100 个带嵌套选择集的顶层字段 | Lexer + Parser + AST 构建 |
| print-100 | 已解析的 100 字段文档 | AST 格式化输出 |
| validate-100 | 已解析的 Schema 和 100 字段文档 | 基础及 Schema 感知验证 |
| pipeline-100 | 100 字段查询 | parse → validate → print |

## 运行方式

```sh
moon bench --release --target native -p eisem/moon_graphql/benchmark
```

也可以检查其他后端：

```sh
moon bench --release --target js -p eisem/moon_graphql/benchmark
moon bench --release --target wasm-gc -p eisem/moon_graphql/benchmark
```

## 结果解释

- 使用 release 构建进行性能比较；
- benchmark 会自动选择批次数并报告统计结果；
- 不同 CPU、操作系统、MoonBit 版本和后端的绝对数值不能直接比较；
- 提交性能结果时应同时记录 Git commit、`moon version --all`、操作系统、CPU 和完整命令；
- 当前基准用于发现项目自身的性能回归，不宣称已经快于 `graphql-js` 或 Rust `graphql-parser`。

跨语言比较需要为三个实现固定版本、使用语义等价的 AST 工作量和同一组输入，并分别区分 parse-only 与 parse-and-validate。项目后续会在满足这些条件后再公布跨语言数据。

## 本机基线

测量日期：2026-07-10；系统：Windows；CPU：Intel Core i9-14900HX（24 核、32 线程）；MoonBit：`moon 0.1.20260608`、`moonc 0.10.0+e66899a54`；命令：

```sh
moon bench --release --target native -p eisem/moon_graphql/benchmark --deny-warn
```

| 场景 | 平均耗时 | 标准差 | 单次测量范围 |
| --- | ---: | ---: | ---: |
| parse-10 | 47.29 µs | 1.01 µs | 46.09–48.82 µs |
| parse-100 | 451.42 µs | 4.62 µs | 446.40–458.73 µs |
| print-100 | 33.31 µs | 0.51 µs | 32.83–34.42 µs |
| validate-100 | 241.55 µs | 4.28 µs | 235.97–248.98 µs |
| pipeline-100 | 938.13 µs | 106.51 µs | 809.23 µs–1.09 ms |

以上数据仅作为当前实现的回归基线，不代表其他硬件上的性能，也不构成跨语言性能结论。
