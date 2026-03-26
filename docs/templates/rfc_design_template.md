# RFC 设计文档模板 (PaddlePaddle Community Standard)

> **Source**: https://github.com/PaddlePaddle/community/blob/master/rfcs/design_template.md
>
> All RFC-required tasks (marked "是" in the
> [RFC需求列表](https://github.com/PaddlePaddle/community/blob/master/hackathon/hackathon_9th/%E3%80%90Hackathon_9th%E3%80%91%E5%BC%80%E6%BA%90%E8%B4%A1%E7%8C%AE%E4%B8%AA%E4%BA%BA%E6%8C%91%E6%88%98%E8%B5%9Brfc%E9%9C%80%E6%B1%82%E5%88%97%E8%A1%A8.md))
> **must** submit an RFC as a PR to `PaddlePaddle/community/rfcs/<Category>/`.
>
> For FastDeploy tasks: `PaddlePaddle/community/rfcs/FastDeploy/`

---

## Mandatory Header Table

```markdown
# 标题 (Title — matches task name)

| 任务名称 | 【Hackathon 9th No.XX】<任务名称> |
|---|---|
| 提交作者 | <GitHub username> |
| 提交时间 | YYYY-MM-DD |
| 版本号 | V1.0 |
| 依赖飞桨版本 | develop |
| 文件名 | YYYYMMDD_<short_description>.md |
```

## Mandatory Sections (一 through 八)

```markdown
# 一、概述
## 1、相关背景
## 2、功能目标
## 3、意义

# 二、飞桨现状
(Current state of the framework — what exists, what's broken)

# 三、业内方案调研
(How vLLM, TGI, SGLang, etc. solve the same problem)

# 四、对比分析
(Compare approaches from §三, justify your choice)

# 五、设计思路与实现方案
## 1、主体设计思路与折衷
## 2、关键技术点/子模块设计与实现方案
## 3、主要影响的模块接口变化

# 六、测试和验收的考量
(How to verify the work succeeded — metrics, tests, acceptance criteria)

# 七、影响面
## 对用户的影响
## 对二次开发用户的影响
## 对框架架构的影响
## 对性能的影响
## 其他风险

# 八、排期规划
(Timeline, milestones)

# 名词解释
# 附件及参考资料
```

## File Naming Convention

```
YYYYMMDD_<short_snake_case_description>.md
```

**Examples from accepted RFCs:**
- `20250909_speed_up_compilation_for_fastdeploy.md` (No.86, 84 lines)
- `20250916_add_minimax_m1_for_fastdeploy.md` (No.93, 222 lines)
- `20251114_add_minicpmV41_for_fastdeploy.md` (No.74)

## Submission Process

1. Fork `PaddlePaddle/community`
2. Create file: `rfcs/FastDeploy/YYYYMMDD_<description>.md`
3. Open PR with title: `【Hackathon 9th No.XX】【RFC】<description>`
4. Wait for Baidu reviewer approval before starting implementation

## Key Principles (from template notes)

> 1. 原则上请使用中文。(Write in Chinese)
> 2. 侧重阐述设计思路而不只是实现方案细节。(Focus on design thinking, not implementation details)
> 3. 体现对方案选型的利弊考量。(Show trade-off analysis for design choices)
> 4. 多利用图表来阐述设计思路。(Use diagrams and tables)

## Length Guidelines

Based on accepted FastDeploy RFCs:
- **Minimum**: ~80 lines (Task 86 compilation — straightforward optimization)
- **Typical**: ~150-220 lines (Task 93 MiniMax-M1 — new model integration)
- **Maximum**: ~300 lines (complex multi-phase projects)

**Do NOT** write 600+ line RFCs. Keep it concise — reviewers will not read walls of text.
The detailed implementation plan can live in your checkpoint `design/` directory as internal docs.
