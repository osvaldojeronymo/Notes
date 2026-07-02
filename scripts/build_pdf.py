#!/usr/bin/env python3
from __future__ import annotations

import argparse
import platform
import re
import shutil
import subprocess
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

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
    }    
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

    pandoc_cmd = [
        "pandoc",
        str(entrada.relative_to(ROOT)),
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

    print(f"\nPDF gerado com sucesso: {pdf}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Gera PDF a partir de Markdown.")
    parser.add_argument("alvo", nargs="?", default="caderno")
    args = parser.parse_args()

    gerar(args.alvo)


if __name__ == "__main__":
    main()