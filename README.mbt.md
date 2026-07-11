# eisem/moon_graphql

`moon_graphql` 是使用 MoonBit 原创实现的 GraphQL 语言处理工具库，提供词法分析、查询与 Schema 解析、AST、规范验证以及格式化输出能力。

本项目定位为 GraphQL 语言基础设施，可作为 GraphQL Server、Client、代码生成器、Linter、Formatter 和 IDE 工具的底层组件；它目前不是包含执行器、Resolver 和网络传输层的 GraphQL Server Runtime。

- 目标规范：[GraphQL Specification, October 2021 Edition](https://spec.graphql.org/October2021/)
- 规范覆盖：[CONFORMANCE.md](CONFORMANCE.md)
- 开源许可证：[Apache-2.0](LICENSE)

## 项目价值

GraphQL 的解析器、AST 和验证器是服务器、客户端与开发工具共同依赖的基础设施。`moon_graphql` 为 MoonBit 生态提供一套原生实现，使后续项目无须通过 JavaScript FFI 或外部服务处理 GraphQL 文档。

当前项目具备以下特点：

- 使用 MoonBit 原生类型、枚举、模式匹配和错误处理实现，核心库无第三方依赖；
- 同时覆盖 GraphQL 查询语言和 Schema Definition Language（SDL）；
- 支持 `parse → validate → print` 完整语言处理流程；
- 对数字、Unicode 字符串、Block String、Fragment、Union、变量和输入值进行规范化检查；
- 提供 153 个自动化测试及 GitHub Actions CI；
- 提供基于 MoonBit 官方 `moon bench` 的 parse/validate/print 性能回归基线；
- 明确记录已支持、部分支持和暂未实现的规范能力，避免模糊的“完整支持”声明。

## 安装

```sh
moon add eisem/moon_graphql
```

## 快速开始

### 解析 GraphQL 查询

```mbt check
///|
test "解析 GraphQL 查询" {
  let input =
    #|query HeroQuery($id: ID!) {
    #|  hero(id: $id) {
    #|    name
    #|  }
    #|}
  let document = @parser.parse(input)
  assert_true(document.definitions.length() == 1)
}
```

### 解析 GraphQL Schema

```mbt check
///|
test "解析 GraphQL Schema" {
  let input =
    #|type Query {
    #|  hero(episode: Episode): Hero
    #|}
    #|type Hero {
    #|  name: String
    #|  friends: [Hero]
    #|}
  let schema = @parser.parse(input)
  assert_true(schema.definitions.length() == 2)
}
```

### 格式化输出 AST

```mbt check
///|
test "格式化 GraphQL 文档" {
  let document = @parser.parse("{ hero { name } }")
  let output = @printer.print(document)
  inspect(
    output,
    content=(
      #|{
      #|  hero {
      #|    name
      #|  }
      #|}
    ),
  )
}
```

### 基础文档验证

```mbt check
///|
test "检查未定义的 Fragment" {
  let document = @parser.parse("{ hero { ...missing } }")
  let errors = @validation.validate(document)
  assert_true(errors.length() > 0)
}
```

### 根据 Schema 验证查询

```mbt check
///|
test "根据 Schema 验证查询" {
  let schema_input =
    #|type Query { hero: Hero }
    #|type Hero { name: String }
  let schema = @parser.parse(schema_input)
  let query = @parser.parse("{ hero { name } }")
  let errors = @validation.validate_against_schema(query, schema)
  assert_true(errors.is_empty())
}
```

### 运行 CLI 演示

```sh
moon run cmd/main
```

CLI 会展示查询与 Schema 的解析、验证和格式化输出流程。

### 使用 Formatter / Linter CLI

项目同时提供两个可直接运行的下游工具：

```sh
# 格式化 GraphQL 文档
moon run cmd/format -- "{ hero { name } }"

# 检查格式是否已经规范化
moon run cmd/format -- --check "{ hero { name } }"

# 执行文档级 Lint 检查
moon run cmd/lint -- "{ hero { ...missing } }"
```

这两个命令展示了 `parser`、`printer` 和 `validation` 包如何组合成实际开发工具。当前 Linter 进行文档级检查；带 Schema 的查询检查仍可通过库 API `validate_against_schema` 完成。

## 已实现能力

### 词法分析

- 严格处理 GraphQL 整数、浮点数、指数、前导零和数字终止规则；
- 支持标准字符串转义、BMP Unicode 转义和 Unicode 代理对；
- 拒绝非法转义、残缺 Unicode、原始换行和非法控制字符；
- 支持 Block String 三引号转义、换行标准化和公共缩进移除；
- 支持 BOM，并正确跟踪 CR、LF、CRLF 的行列位置。

### 查询语言

- `query`、`mutation`、`subscription`；
- 命名操作与匿名查询简写；
- 字段、别名、参数和嵌套选择集；
- Int、Float、String、Boolean、Null、Enum、List、Object 等值类型；
- 变量定义、默认值和类型引用；
- 命名 Fragment、Fragment Spread 和 Inline Fragment；
- Directive。

### Schema Definition Language

- Object、Interface、Union、Enum、Input Object、Scalar；
- Schema 根操作类型定义；
- 字段参数、输入字段和默认值；
- 类型描述字符串；
- Interface 实现关系；
- Directive 定义、位置和 `repeatable`。

### 文档与 Schema 感知验证

- Fragment 与操作名称唯一性；
- Fragment 引用存在性和循环检测；
- 匿名操作唯一性；
- 变量名称、声明类型、默认值、引用范围和参数位置兼容性；
- 未使用变量与未使用 Fragment 检查；
- 字段存在性与叶子/复合类型选择集检查；
- 参数存在性、唯一性、必填参数和输入值 coercion；
- 标量、Enum、List、Input Object 和 Non-Null 输入检查；
- 内建及 Schema 自定义 Directive 的名称、位置、重复性和参数检查；
- Named/Inline Fragment 字段验证；
- Union 的 `__typename` 和类型条件 Fragment 验证；
- 结构化 `ValidationError`，支持错误信息与严重级别判断。

## 当前边界

项目正在持续扩展 GraphQL 规范覆盖。目前尚未完整实现：

- GraphQL 执行器、Resolver、Introspection 执行和网络传输；
- SDL `extend` 类型系统扩展；
- 字段合并冲突检查和 Fragment possible-type overlap；
- 自定义 Scalar 的应用层 coercion；
- 完整 Schema 合法性验证。

详细状态及测试来源请查看 [GraphQL 规范覆盖矩阵](CONFORMANCE.md)。

## 性能基准

仓库提供 10/100 字段查询的解析、打印、验证和完整流水线 benchmark。测试方法、运行命令、本机环境和基线结果见 [BENCHMARKS.md](BENCHMARKS.md)。这些数据用于发现性能回归；在建立相同语料、固定依赖版本和等价工作量之前，项目不会宣称快于 `graphql-js` 或 Rust `graphql-parser`。

## 工程质量检查

```sh
moon check --deny-warn
moon test --deny-warn
moon fmt --check
moon run cmd/main
```

上述命令也由仓库的 GitHub Actions CI 执行。

## 项目结构

```text
moon_graphql/
  ast/           # AST 类型、位置信息和辅助方法
  lexer/         # GraphQL 词法分析器
  parser/        # 查询语言与 SDL 解析器
  printer/       # AST 格式化输出
  validation/    # 文档及 Schema 感知验证
  integration/   # 端到端集成测试
  cmd/main/      # parse → validate → print CLI 演示
```

## 实现与参考说明

本项目为 MoonBit 原创实现，不是对其他 GraphQL 库源代码的直接移植。设计和行为以 GraphQL October 2021 公开规范为依据；测试用例为根据规范行为编写的最小原创用例，未复制 `graphql-js` 或其他实现的测试夹具与源代码。
