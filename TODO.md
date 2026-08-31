# TODO

## Neovim Config 확장

현재 `config/nvim/`에는 lazy.nvim 부트스트랩과 yazi.nvim 플러그인만 있다. 실질적인 편집 환경이 없는 상태.

- [ ] LSP 설정 — `nvim-lspconfig` + Mason으로 언어 서버 자동 설치
- [ ] 구문 강조 — `nvim-treesitter`
- [ ] 자동완성 — `nvim-cmp` + 소스 (LSP, buffer, path)
- [ ] 색상 테마 — `tokyonight` 또는 `catppuccin`
- [ ] 파일 탐색 — 현재 yazi.nvim으로 대체 가능, 필요 시 `telescope.nvim` 추가
- [ ] 상태표시줄 — `lualine.nvim`

## Freshness Check 자동화

현재 `.github/workflows/freshness-check.yml`은 매주 월요일 업스트림 최신 태그를 조회해 artifact로만 저장한다. 버전 변경에 반응하는 기능이 없다.

- [ ] 버전 변경 감지 시 GitHub Issue 자동 생성 또는 PR 자동 오픈
- [ ] 또는 Renovate Bot 도입으로 `manifests/apt.txt`, `manifests/Brewfile` 핀 버전 관리
- [ ] 현재 설치된 버전 vs 최신 버전 diff를 report에 포함
