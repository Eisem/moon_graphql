moon_graphql 项目申报书

基本信息

项目名称：moon_graphql：MoonBit 生态 GraphQL 解析器与工具库

参赛者：[你的姓名]

联系方式：[手机号]

GitHub 仓库链接：https://github.com/Eisem/moon_graphql

Gitlink 仓库链接：[同步后填写]

项目方向：工程基础设施与工具链 / 面向特定格式的解析工具

是否为移植项目：否（原创实现，参考 GraphQL 官方公开规范）

项目简介

moon_graphql 为 MoonBit 生态提供完整的 GraphQL 语言解析与处理能力，包括词法分析、语法分析、AST 表示、文档验证和格式化输出五大核心模块。项目覆盖 GraphQL 查询语言（Query/Mutation/Subscription、Fragment、Variable、Directive）和类型系统定义语言（Object/Interface/Union/Enum/Input/Scalar），能够解析符合 GraphQL 规范的文档并产出结构化 AST，支持 schema 感知的查询验证以及 AST 到格式化文本的反向输出。GraphQL 作为现代 API 开发的主流协议（被 GitHub API v4、Shopify、Meta 等广泛采用），是 Web 生态中不可或缺的基础设施。当前 MoonBit 生态中不存在任何 GraphQL 相关工具，moon_graphql 填补了这一空白，为后续在 MoonBit 中构建 GraphQL 服务器、客户端、代码生成器、Linter 和 Formatter 提供核心解析基础。

核心功能范围

完整的 GraphQL 词法分析器，支持全部标点符号、名称标识符、整数/浮点数字面量、单行字符串（含转义序列）、块字符串（三引号）、注释跳过、逗号忽略和 spread 操作符；

GraphQL 查询解析器，解析 query/mutation/subscription 操作定义，支持命名操作、匿名查询简写、变量定义与类型标注、指令、字段选择集、参数与默认值、别名、内联 Fragment 和 Fragment Spread；

GraphQL 类型系统解析器，解析 type/interface/union/enum/input/scalar/schema/directive 定义，支持描述字符串、字段定义与参数、默认值、implements 接口列表、union 成员列表和 directive 位置声明；

完整的 AST 类型定义，覆盖 Document、OperationDef、FragmentDef、SelectionSet、FieldNode、TypeRef、Value、以及全部类型系统定义节点；

AST 格式化打印器，将解析后的 AST 反向输出为缩进格式化的 GraphQL 文本，支持完整的 roundtrip 验证（parse → print → parse 结果一致）；

文档验证器，包括基础验证（Fragment 名称唯一性、Fragment 引用存在性、操作名称唯一性、变量定义与使用检查）和 Schema 感知验证（字段存在性验证、必填参数完整性检查）；

CLI 演示工具，展示完整的 parse → validate → print 处理流程；

提供 95 个自动化测试，覆盖词法分析、查询解析、Schema 解析、打印输出、文档验证和集成测试全部核心路径；

提供 GitHub Actions CI 配置，自动执行 check、build、test、fmt 检查；

提供 README 文档，包含安装方式、使用示例和项目结构说明。

参考说明

本项目为原创实现，非移植项目。

参考规范：GraphQL Specification, October 2021 Edition

规范链接：https://spec.graphql.org/October2021/

参考设计思路的实现：Rust graphql-parser (https://github.com/graphql-rust/graphql-parser, MIT)、JavaScript graphql-js (https://github.com/graphql/graphql-js, MIT)

本项目许可证：Apache-2.0

本项目所有代码基于 GraphQL 公开技术规范独立编写，未复制或翻译任何参考实现的源代码。项目使用 MoonBit 原生类型系统、枚举、模式匹配、错误处理和包管理机制重新设计全部 API 接口和内部结构，与参考实现在代码层面无直接对应关系。
