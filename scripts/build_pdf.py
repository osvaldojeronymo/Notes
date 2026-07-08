#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import platform
import re
import shutil
import subprocess
import tempfile
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MERMAID_BLOCK_RE = re.compile(r"```mermaid\s*\n(.*?)\n```", re.DOTALL)

CONFIGS = {
    "caderno": {
        "input": "content/relatorios/executivo/caderno-de-visao-geral.md",
        "template": "templates/caderno-template.html",
        "output_html": "caderno-de-visao-geral.html",
        "output_pdf": "caderno-de-visao-geral.pdf",
    },

    "metas": {
        "input": "content/relatorios/executivo/caderno-de-visao-metas.md",
        "template": "templates/caderno-template.html",
        "output_html": "caderno-de-visao-metas.html",
        "output_pdf": "caderno-de-visao-metas.pdf",
    },
    
    "material": {
        "input": "content/informe-executivo/mr_01.md",
        "template": "templates/caderno-template.html",
        "output_html": "entrega-de-materiais.html",
        "output_pdf": "entrega-de-materiais.pdf",
    },
    "arq-msg": {
        "input": "content/relatorios/arquitetura-dados/01_mensagem-executiva-arquitetura-dados.md",
        "template": "templates/caderno-template.html",
        "output_html": "arquitetura-dados-mensagem-executiva.html",
        "output_pdf": "arquitetura-dados-mensagem-executiva.pdf",
    },
    "arq-rel": {
        "input": "content/relatorios/arquitetura-dados/02_relatorio-analitico-arquitetura-dados.md",
        "template": "templates/caderno-template.html",
        "output_html": "arquitetura-dados-relatorio-analitico.html",
        "output_pdf": "arquitetura-dados-relatorio-analitico.pdf",
    },
    "arq-ref": {
        "input": "content/relatorios/arquitetura-dados/03_referencia-tecnica-arquitetura-dados.md",
        "template": "templates/caderno-template.html",
        "output_html": "arquitetura-dados-referencia-tecnica.html",
        "output_pdf": "arquitetura-dados-referencia-tecnica.pdf",
    },
    "arq-apr": {
        "input": "content/relatorios/arquitetura-dados/04_apresentacao-executiva-arquitetura-dados.md",
        "template": "templates/caderno-template.html",
        "output_html": "arquitetura-dados-apresentacao-executiva.html",
        "output_pdf": "arquitetura-dados-apresentacao-executiva.pdf",
    },
    "arq-apr-dir": {
        "input": "content/relatorios/arquitetura-dados/05_apresentacao-diretoria-arquitetura-dados.md",
        "template": "templates/caderno-template.html",
        "output_html": "arquitetura-dados-apresentacao-diretoria.html",
        "output_pdf": "arquitetura-dados-apresentacao-diretoria.pdf",
    },
    "an-onepage": {
        "input": "content/relatorios/executivo/arquivo-nacional-one-page.md",
        "template": "templates/caderno-template.html",
        "output_html": "arquivo-nacional-one-page.html",
        "output_pdf": "arquivo-nacional-one-page.pdf",
    },
}

GROUPS = {
    "arquitetura-dados": ["arq-msg", "arq-rel", "arq-ref", "arq-apr", "arq-apr-dir"],
    "todos": list(CONFIGS.keys()),
}

def data_pt_br() -> str:
    meses = [
        "janeiro", "fevereiro", "março", "abril", "maio", "junho",
        "julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
    ]
    hoje = datetime.now()
    return f"{hoje.day:02d} de {meses[hoje.month - 1]} de {hoje.year}"


def ler_front_matter(md_path: Path) -> dict[str, str]:
    texto = md_path.read_text(encoding="utf-8")

    match = re.match(r"^---\s*\n(.*?)\n---\s*\n", texto, re.DOTALL)
    if not match:
        return {}

    dados: dict[str, str] = {}

    for linha in match.group(1).splitlines():
        if ":" not in linha:
            continue

        chave, valor = linha.split(":", 1)
        chave = chave.strip()
        valor = valor.strip().strip('"').strip("'")

        dados[chave] = valor

    return dados


def encontrar_chrome() -> str:
    if platform.system() == "Windows":
        candidatos = [
            shutil.which("chrome"),
            shutil.which("chrome.exe"),
            r"C:\Program Files\Google\Chrome\Application\chrome.exe",
            r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
            r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
            r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        ]
    else:
        candidatos = [
            shutil.which("google-chrome"),
            shutil.which("google-chrome-stable"),
            shutil.which("chromium"),
            shutil.which("chromium-browser"),
            shutil.which("microsoft-edge"),
        ]

    for candidato in candidatos:
        if candidato and Path(candidato).exists():
            return str(candidato)

    raise FileNotFoundError("Chrome, Chromium ou Edge não encontrado.")


def executar(cmd: list[str]) -> None:
    print("\n> " + " ".join(f'"{c}"' if " " in c else c for c in cmd))
    subprocess.run(cmd, cwd=ROOT, check=True)


def preparar_markdown_com_mermaid(md_path: Path) -> tuple[Path, list[Path]]:
    texto = md_path.read_text(encoding="utf-8")
    blocos = list(MERMAID_BLOCK_RE.finditer(texto))

    if not blocos:
        return md_path, []

    mmdc = shutil.which("mmdc")
    if not mmdc:
        raise FileNotFoundError(
            "Foram encontrados blocos Mermaid no Markdown, mas o comando 'mmdc' não está no PATH. "
            "Instale com: npm install -g @mermaid-js/mermaid-cli"
        )

    mermaid_dir = ROOT / "assets" / "mermaid"
    mermaid_dir.mkdir(parents=True, exist_ok=True)

    cleanup_paths: list[Path] = []
    saida_partes: list[str] = []
    cursor = 0

    for idx, bloco in enumerate(blocos, start=1):
        codigo = bloco.group(1).strip() + "\n"
        hash_curto = hashlib.sha1(codigo.encode("utf-8")).hexdigest()[:10]
        diagrama_svg = mermaid_dir / f"{md_path.stem}-diagram-{idx}-{hash_curto}.svg"
        mermaid_src = mermaid_dir / f".{md_path.stem}-diagram-{idx}-{hash_curto}.mmd"

        mermaid_src.write_text(codigo, encoding="utf-8")
        cleanup_paths.append(mermaid_src)

        executar([
            mmdc,
            "-i",
            str(mermaid_src),
            "-o",
            str(diagrama_svg),
            "-b",
            "transparent",
            "-t",
            "neutral",
        ])

        saida_partes.append(texto[cursor:bloco.start()])
        rel_svg = diagrama_svg.relative_to(ROOT).as_posix()
        contexto = texto[:bloco.start()]
        heading_match = re.findall(r"^#{1,6}\s+(.+)$", contexto, flags=re.MULTILINE)
        if heading_match:
            heading_text = heading_match[-1].strip()
            heading_text = re.sub(r"^\d+[\.)]?\s*", "", heading_text)
            legenda = f"Figura {idx} - Fluxograma do {heading_text.lower()}"
        else:
            legenda = f"Figura {idx} - Fluxograma do processo"
        saida_partes.append(
            f"![{legenda}]({rel_svg})\n\n"
            "<p class=\"abnt-table-source\">Fonte: Elaboração própria.</p>\n"
        )
        cursor = bloco.end()

    saida_partes.append(texto[cursor:])
    texto_processado = "".join(saida_partes)

    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        suffix=".md",
        prefix=".build-mermaid-",
        dir=ROOT,
        delete=False,
    ) as tmp_md:
        tmp_md.write(texto_processado)
        tmp_path = Path(tmp_md.name)

    cleanup_paths.append(tmp_path)
    return tmp_path, cleanup_paths


def gerar(alvo: str) -> None:
    if alvo not in CONFIGS:
        raise ValueError(f"Alvo desconhecido: {alvo}. Disponíveis: {', '.join(CONFIGS)}")

    cfg = CONFIGS[alvo]

    entrada = ROOT / cfg["input"]
    template = ROOT / cfg["template"]
    html = ROOT / cfg["output_html"]
    pdf = ROOT / cfg["output_pdf"]

    if not entrada.exists():
        raise FileNotFoundError(f"Markdown não encontrado: {entrada}")

    if not template.exists():
        raise FileNotFoundError(f"Template não encontrado: {template}")

    if not shutil.which("pandoc"):
        raise FileNotFoundError("Pandoc não encontrado no PATH.")

    chrome = encontrar_chrome()
    meta = ler_front_matter(entrada)

    if meta.get("date", "").lower() in ("", "auto"):
        meta["date"] = data_pt_br()

    meta["report_date"] = meta["date"]

    # Se não houver date no Markdown, usa a data automática.
    meta.setdefault("date", data_pt_br())
    meta.setdefault("report_date", meta["date"])

    # Se não houver rodapé no Markdown, cria valores padrão.
    meta.setdefault("footer_left", "#INTERNO.TODOS | Convênio CAIXA-UnB")
    meta.setdefault("footer_center", meta.get("title", "Caderno Executivo"))

    entrada_pandoc, paths_limpeza = preparar_markdown_com_mermaid(entrada)

    try:
        pandoc_cmd = [
            "pandoc",
            str(entrada_pandoc.relative_to(ROOT)),
            "--template", str(template.relative_to(ROOT)),
        ]

        for chave, valor in meta.items():
            pandoc_cmd.extend(["--metadata", f"{chave}={valor}"])

        pandoc_cmd.extend(["-o", str(html.relative_to(ROOT))])

        executar(pandoc_cmd)

        executar([
            chrome,
            "--headless",
            "--disable-gpu",
            "--no-pdf-header-footer",
            f"--print-to-pdf={pdf}",
            str(html),
        ])
    finally:
        for path in paths_limpeza:
            try:
                if path.exists():
                    path.unlink()
            except OSError:
                pass

    print(f"\nPDF gerado com sucesso: {pdf}")


def gerar_grupo(nome_grupo: str) -> None:
    if nome_grupo not in GROUPS:
        raise ValueError(f"Grupo desconhecido: {nome_grupo}. Disponíveis: {', '.join(GROUPS)}")

    for alvo in GROUPS[nome_grupo]:
        print(f"\n=== Gerando alvo: {alvo} ===")
        gerar(alvo)


def main() -> None:
    parser = argparse.ArgumentParser(description="Gera PDF a partir de Markdown.")
    parser.add_argument("alvo", nargs="?", default="caderno")
    args = parser.parse_args()

    if args.alvo in GROUPS:
        gerar_grupo(args.alvo)
        return

    gerar(args.alvo)


if __name__ == "__main__":
    main()