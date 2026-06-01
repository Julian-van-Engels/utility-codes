# Jotting

一些实用小工具。

---

- **[setup-zsh.sh](setup-zsh.sh)** — Zsh 环境一键配置脚本，兼容 macOS / Linux。安装 zsh、Oh My Zsh、插件、eza/yazi/trash-cli/opencode 等工具，自动迁移旧配置。

- **[cpu_benchmark.py](cpu_benchmark.py)** — 单核 CPU 性能测试，纯标准库。9 项测试覆盖整数、浮点、质数筛、矩阵乘、SHA-256 等场景。

- **[generate_report.py](generate_report.py)** — 从 Git 仓库拉取指定时间范围内的提交，生成 Obsidian 风格的周报/报告，含总结区和详细列表。

- **[compare_2folder_diff.py](compare_2folder_diff.py)** — 多线程递归比较两个文件夹，输出差异报告。
  ```bash
  python compare_2folder_diff.py <目录A> <目录B>
  ```

---

[MIT](LICENSE)
