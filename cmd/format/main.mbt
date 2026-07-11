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
  let check_only = args.length() > 1 && args[1] == "--check"
  let input_args = if check_only { args[2:] } else { args[1:] }
  if input_args.is_empty() {
    println("用法: moon run cmd/format -- [--check] <GraphQL 文档>")
    return
  }
  let input = collect_input(input_args)
  let document = @parser.parse(input) catch {
    error => {
      println("解析失败: \{error}")
      @abort.abort("无法格式化无效的 GraphQL 文档")
    }
  }
  let formatted = @printer.print(document)
  if check_only {
    if formatted == input {
      println("格式检查通过")
    } else {
      println("格式检查失败，格式化结果如下：")
      println(formatted)
      @abort.abort("GraphQL 文档未按规范格式化")
    }
  } else {
    println(formatted)
  }
}
