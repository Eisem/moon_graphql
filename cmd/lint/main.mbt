///|
fn collect_input(args : ArrayView[String]) -> String {
  let output = StringBuilder::new()
  for i in 0..<args.length() {
    if i > 0 {
      output.write_char(' ')
    }
    output.write_string(args[i])
  }
  output.to_string()
}

///|
fn main {
  let args = @env.args()
  if args.length() <= 1 {
    println("用法: moon run cmd/lint -- <GraphQL 文档>")
    return
  }
  let document = @parser.parse(collect_input(args[1:])) catch {
    error => {
      println("解析失败: \{error}")
      @abort.abort("无法检查无效的 GraphQL 文档")
    }
  }
  let errors = @validation.validate(document)
  if errors.is_empty() {
    println("Lint 通过：未发现文档级错误")
  } else {
    println("Lint 发现 \{errors.length()} 个问题：")
    for error in errors {
      println("- \{error.message()}")
    }
    @abort.abort("Lint 检查失败")
  }
}
