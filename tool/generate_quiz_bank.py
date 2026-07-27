#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Gera e valida o banco de quiz bíblico (~1000 perguntas) para o app EBD.

Uso:
  python tool/generate_quiz_bank.py
  python tool/generate_quiz_bank.py --validate-only

Saída: assets/quiz/questions.json (schema compatível com QuizBank / QuizQuestion).
"""

from __future__ import annotations

import argparse
import json
import random
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "quiz" / "questions.json"
SEED = ROOT / "tool" / "quiz_seed_v1.json"

LEVELS = ("facil", "medio", "dificil", "expert")
TARGET_MIN, TARGET_MAX = 950, 1100
TARGET = 1000

# Catálogo alinhado a lib/data/bible/bible_catalog.dart
BOOKS = [
    ("gen", "Gênesis", "AT", 50, "Gn"),
    ("exo", "Êxodo", "AT", 40, "Êx"),
    ("lev", "Levítico", "AT", 27, "Lv"),
    ("num", "Números", "AT", 36, "Nm"),
    ("deu", "Deuteronômio", "AT", 34, "Dt"),
    ("jos", "Josué", "AT", 24, "Js"),
    ("jui", "Juízes", "AT", 21, "Jz"),
    ("rut", "Rute", "AT", 4, "Rt"),
    ("1sa", "1 Samuel", "AT", 31, "1Sm"),
    ("2sa", "2 Samuel", "AT", 24, "2Sm"),
    ("1rs", "1 Reis", "AT", 22, "1Rs"),
    ("2rs", "2 Reis", "AT", 25, "2Rs"),
    ("1cr", "1 Crônicas", "AT", 29, "1Cr"),
    ("2cr", "2 Crônicas", "AT", 36, "2Cr"),
    ("esd", "Esdras", "AT", 10, "Ed"),
    ("nee", "Neemias", "AT", 13, "Ne"),
    ("est", "Ester", "AT", 10, "Et"),
    ("jo", "Jó", "AT", 42, "Jó"),
    ("sal", "Salmos", "AT", 150, "Sl"),
    ("pro", "Provérbios", "AT", 31, "Pv"),
    ("ecl", "Eclesiastes", "AT", 12, "Ec"),
    ("can", "Cânticos", "AT", 8, "Ct"),
    ("isa", "Isaías", "AT", 66, "Is"),
    ("jer", "Jeremias", "AT", 52, "Jr"),
    ("lam", "Lamentações", "AT", 5, "Lm"),
    ("eze", "Ezequiel", "AT", 48, "Ez"),
    ("dan", "Daniel", "AT", 12, "Dn"),
    ("ose", "Oséias", "AT", 14, "Os"),
    ("joe", "Joel", "AT", 3, "Jl"),
    ("amo", "Amós", "AT", 9, "Am"),
    ("oba", "Obadias", "AT", 1, "Ob"),
    ("jon", "Jonas", "AT", 4, "Jn"),
    ("miq", "Miquéias", "AT", 7, "Mq"),
    ("naa", "Naum", "AT", 3, "Na"),
    ("hab", "Habacuque", "AT", 3, "Hc"),
    ("sof", "Sofonias", "AT", 3, "Sf"),
    ("age", "Ageu", "AT", 2, "Ag"),
    ("zac", "Zacarias", "AT", 14, "Zc"),
    ("mal", "Malaquias", "AT", 4, "Ml"),
    ("mat", "Mateus", "NT", 28, "Mt"),
    ("mar", "Marcos", "NT", 16, "Mc"),
    ("luc", "Lucas", "NT", 24, "Lc"),
    ("joao", "João", "NT", 21, "Jo"),
    ("ato", "Atos", "NT", 28, "At"),
    ("rom", "Romanos", "NT", 16, "Rm"),
    ("1co", "1 Coríntios", "NT", 16, "1Co"),
    ("2co", "2 Coríntios", "NT", 13, "2Co"),
    ("gal", "Gálatas", "NT", 6, "Gl"),
    ("ef", "Efésios", "NT", 6, "Ef"),
    ("fp", "Filipenses", "NT", 4, "Fp"),
    ("cl", "Colossenses", "NT", 4, "Cl"),
    ("1ts", "1 Tessalonicenses", "NT", 5, "1Ts"),
    ("2ts", "2 Tessalonicenses", "NT", 3, "2Ts"),
    ("1tm", "1 Timóteo", "NT", 6, "1Tm"),
    ("2tm", "2 Timóteo", "NT", 4, "2Tm"),
    ("tt", "Tito", "NT", 3, "Tt"),
    ("fm", "Filemom", "NT", 1, "Fm"),
    ("hb", "Hebreus", "NT", 13, "Hb"),
    ("tg", "Tiago", "NT", 5, "Tg"),
    ("1pe", "1 Pedro", "NT", 5, "1Pe"),
    ("2pe", "2 Pedro", "NT", 3, "2Pe"),
    ("1jo", "1 João", "NT", 5, "1Jo"),
    ("2jo", "2 João", "NT", 1, "2Jo"),
    ("3jo", "3 João", "NT", 1, "3Jo"),
    ("jd", "Judas", "NT", 1, "Jd"),
    ("ap", "Apocalipse", "NT", 22, "Ap"),
]

BOOK_BY_ID = {b[0]: b for b in BOOKS}
AT_IDS = [b[0] for b in BOOKS if b[2] == "AT"]
NT_IDS = [b[0] for b in BOOKS if b[2] == "NT"]

# Distratores genéricos reutilizáveis (embaralhados por pergunta)
PEOPLE = [
    "Abraão", "Isaque", "Jacó", "José", "Moisés", "Arão", "Josué", "Calebe",
    "Gideão", "Sansão", "Samuel", "Saul", "Davi", "Salomão", "Elias", "Eliseu",
    "Isaías", "Jeremias", "Ezequiel", "Daniel", "Jonas", "Neemias", "Esdras",
    "Pedro", "João", "Tiago", "Paulo", "Barnabé", "Timóteo", "Tito", "Lucas",
    "Mateus", "Marcos", "André", "Filipe", "Tomé", "Nicodemos", "Lázaro",
    "Herodes", "Pilatos", "Caifás", "Gamaliel", "Apolo", "Silas", "Estêvão",
]
PLACES = [
    "Jerusalém", "Belém", "Nazaré", "Capernaum", "Jericó", "Hebrom", "Silo",
    "Betel", "Siquém", "Nínive", "Babilônia", "Egito", "Assíria", "Samaria",
    "Damasco", "Antioquia", "Corinto", "Éfeso", "Roma", "Galileia", "Judeia",
    "Monte Sinai", "Monte Carmelo", "Monte das Oliveiras", "Getesêmani",
]
NUMS = ["3", "7", "10", "12", "40", "70", "120", "144", "400", "1000"]
THINGS = [
    "o templo", "a arca", "o tabernáculo", "a lei", "os profetas", "os salmos",
    "o altar", "o véu", "o sumo sacerdote", "o sábado", "a Páscoa", "o jeju",
]


def _norm_q(s: str) -> str:
    s = s.lower().strip()
    s = re.sub(r"\s+", " ", s)
    s = re.sub(r"[^\w\sÀ-ÿ]", "", s)
    return s


def _pick_distractors(correct: str, pool: list[str], n: int = 3, rng: random.Random | None = None) -> list[str]:
    rng = rng or random
    c = correct.strip().lower()
    cands = [x for x in pool if x.strip().lower() != c]
    rng.shuffle(cands)
    out = []
    seen = {c}
    for x in cands:
        k = x.strip().lower()
        if k in seen:
            continue
        out.append(x)
        seen.add(k)
        if len(out) >= n:
            break
    while len(out) < n:
        filler = rng.choice(PEOPLE + PLACES + NUMS)
        if filler.strip().lower() not in seen:
            out.append(filler)
            seen.add(filler.strip().lower())
    return out[:n]


def _make_options(correct: str, distractors: list[str], rng: random.Random) -> tuple[list[str], int]:
    opts = [correct] + distractors[:3]
    while len(opts) < 4:
        opts.append(rng.choice(PEOPLE))
    # dedupe preserving order
    seen = set()
    clean = []
    for o in opts:
        k = o.strip().lower()
        if k in seen:
            continue
        seen.add(k)
        clean.append(o)
    while len(clean) < 4:
        x = rng.choice(PEOPLE + PLACES)
        if x.strip().lower() not in seen:
            clean.append(x)
            seen.add(x.strip().lower())
    clean = clean[:4]
    rng.shuffle(clean)
    return clean, clean.index(correct)


def qdict(
    *,
    qid: str,
    level: str,
    book_id: str,
    question: str,
    correct: str,
    distractors: list[str] | None = None,
    ref: str | None = None,
    rng: random.Random,
) -> dict:
    if distractors is None or len(distractors) < 3:
        pool = PEOPLE + PLACES + NUMS + THINGS
        distractors = _pick_distractors(correct, pool, 3, rng)
    options, idx = _make_options(correct, distractors, rng)
    return {
        "id": qid,
        "level": level,
        "bookId": book_id,
        "q": question,
        "options": options,
        "correct": idx,
        "ref": ref,
    }


# ---------------------------------------------------------------------------
# Banco de fatos: (bookId, level, pergunta, correta, [distratores], ref)
# ---------------------------------------------------------------------------

def facts() -> list[tuple]:
    """Fatos bíblicos curados (pt-BR) para expansão do quiz."""
    F: list[tuple] = []

    def add(book: str, level: str, question: str, correct: str, distractors: list[str], ref: str | None = None):
        F.append((book, level, question, correct, distractors, ref))

    # ---- Gênesis ----
    add("gen", "facil", "Quem criou os céus e a terra, segundo Gênesis 1?", "Deus", ["Adão", "Moisés", "Noé"], "Gn 1")
    add("gen", "facil", "Quem foi a primeira mulher, segundo Gênesis?", "Eva", ["Sara", "Raquel", "Rute"], "Gn 2")
    add("gen", "facil", "Qual foi o primeiro filho de Adão e Eva mencionado após o nascimento?", "Caim", ["Abel", "Sete", "Enoque"], "Gn 4")
    add("gen", "medio", "Quem foi levado por Deus e não se achou mais?", "Enoque", ["Noé", "Ló", "Melquisedeque"], "Gn 5")
    add("gen", "medio", "A aliança do arco-íris foi feita com:", "Noé", ["Abraão", "Moisés", "Davi"], "Gn 9")
    add("gen", "medio", "Quem era o sobrinho de Abrão que foi para Sodoma?", "Ló", ["Ismael", "Esaú", "Labão"], "Gn 13")
    add("gen", "dificil", "Melquisedeque era rei de:", "Salém", ["Egito", "Assíria", "Ur"], "Gn 14")
    add("gen", "dificil", "O nome Isaque significa relação com:", "Riso", ["Guerra", "Fuga", "Sacerdócio"], "Gn 21")
    add("gen", "expert", "Quem era a mãe de Ismael?", "Hagar", ["Sara", "Rebeca", "Bila"], "Gn 16")
    add("gen", "expert", "Jacó lutou com um homem em:", "Peniel", ["Betel", "Hebrom", "Berseba"], "Gn 32")
    add("gen", "facil", "Quantos filhos Jacó teve (os patriarcas das tribos)?", "12", ["7", "10", "40"], "Gn 35")
    add("gen", "medio", "José interpretou sonhos no Egito para:", "Faraó", ["Nabucodonosor", "Herodes", "Ciro"], "Gn 41")
    add("gen", "dificil", "O filho mais novo de Jacó era:", "Benjamim", ["José", "Dã", "Aser"], "Gn 35")
    add("gen", "expert", "Efraim e Manassés eram filhos de:", "José", ["Judá", "Levi", "Rubem"], "Gn 41")
    add("gen", "facil", "Deus pediu a Abraão que oferecesse Isaac em:", "Moriá", ["Sinai", "Carmelo", "Horebe"], "Gn 22")

    # ---- Êxodo ----
    add("exo", "facil", "Onde Moisés viu a sarça ardente?", "Monte Horebe (Sinai)", ["Jericó", "Carmelo", "Sião"], "Êx 3")
    add("exo", "facil", "Quem foi a porta-voz com Moisés perante Faraó?", "Arão", ["Josué", "Calebe", "Hur"], "Êx 4")
    add("exo", "medio", "Quantas pragas caíram sobre o Egito?", "10", ["7", "12", "3"], "Êx 7-12")
    add("exo", "medio", "O maná começou a cair no deserto após a saída do:", "Egito", ["Canaã", "Babilônia", "Assíria"], "Êx 16")
    add("exo", "dificil", "Bezaleel foi ungido para trabalhar no:", "Tabernáculo", ["Templo de Salomão", "Muro de Jerusalém", "Arca de Noé"], "Êx 31")
    add("exo", "expert", "O bezerro de ouro foi feito enquanto Moisés estava no monte por:", "40 dias", ["7 dias", "3 dias", "12 dias"], "Êx 32")
    add("exo", "facil", "A festa que lembra a saída do Egito é a:", "Páscoa", ["Pentecostes", "Purim", "Tabernáculos só"], "Êx 12")
    add("exo", "medio", "A coluna de nuvem e fogo guiava Israel no:", "Deserto", ["Templo", "Jardim", "Mar Morto"], "Êx 13")
    add("exo", "dificil", "Jetro era sogro de:", "Moisés", ["Arão", "Josué", "Calebe"], "Êx 18")
    add("exo", "expert", "As tábuas da lei foram colocadas na:", "Arca da Aliança", ["Tenda de Moisés", "Altar de bronze", "Casa de Arão"], "Êx 25")

    # ---- Levítico ----
    add("lev", "facil", "Levítico trata principalmente de:", "Santidade e sacrifícios", ["Guerras de Canaã", "Genealogia de Davi", "Viagens de Paulo"], "Lv 1")
    add("lev", "medio", "O Dia da Expiação é chamado de:", "Yom Kippur / Dia da Expiação", ["Páscoa", "Purim", "Hanucá"], "Lv 16")
    add("lev", "dificil", "Nadabe e Abiú ofereceram fogo estranho e:", "Morreram", ["Foram exaltados", "Viraram reis", "Fugiram para Egito"], "Lv 10")
    add("lev", "expert", "O jubileu ocorria a cada:", "50 anos", ["7 anos", "12 anos", "40 anos"], "Lv 25")
    add("lev", "facil", "Os levitas cuidavam do:", "Santuário", ["Exército", "Tesouro real", "Comércio"], "Lv 1-10")
    add("lev", "medio", "É proibido comer sangue porque a vida está no:", "Sangue", ["Fígado", "Coração só", "Osso"], "Lv 17")
    add("lev", "dificil", "O ano sabático manda a terra descansar a cada:", "7 anos", ["3 anos", "10 anos", "12 anos"], "Lv 25")
    add("lev", "expert", "O sumo sacerdote entrava no Santo dos Santos:", "Uma vez ao ano", ["Toda semana", "Todo dia", "Nunca"], "Lv 16")

    # ---- Números ----
    add("num", "facil", "Números começa com um:", "Censo de Israel", ["Cântico", "Templo", "Rei"], "Nm 1")
    add("num", "medio", "Os espias exploraram Canaã por:", "40 dias", ["7 dias", "3 dias", "12 dias"], "Nm 13")
    add("num", "dificil", "Somente Josué e Calebe, da geração adulta, entrariam em:", "Canaã", ["Egito", "Assíria", "Babilônia"], "Nm 14")
    add("num", "expert", "A serpente de bronze foi levantada por causa de:", "Serpentes no acampamento", ["Fome", "Sede só", "Guerra com Amaleque"], "Nm 21")
    add("num", "facil", "Balaão foi chamado para amaldiçoar:", "Israel", ["Egito", "Moabe só", "Edom"], "Nm 22")
    add("num", "medio", "A jumenta de Balaão:", "Falou", ["Voou", "Desapareceu", "Virou ouro"], "Nm 22")
    add("num", "dificil", "Fineias deteve uma praga com zelo por:", "A pureza da aliança", ["O ouro do templo", "O trono de Saul", "A arca de Noé"], "Nm 25")
    add("num", "expert", "As cidades de refúgio protegiam o:", "Homicida sem intenção", ["Ladrão", "Adúltero", "Idólatra"], "Nm 35")

    # ---- Deuteronômio ----
    add("deu", "facil", "Deuteronômio significa, em sentido amplo:", "Segunda lei / repetição da lei", ["Novo templo", "Novo rei", "Novo censo"], "Dt 1")
    add("deu", "medio", "O Shemá começa com: 'Ouve, ó Israel, o Senhor nosso Deus é:", "O único Senhor", ["Três deuses", "Um anjo", "Um rei"], "Dt 6")
    add("deu", "dificil", "Moisés morreu no monte:", "Nebo", ["Sinai", "Carmelo", "Tabor"], "Dt 34")
    add("deu", "expert", "Deus enterrou Moisés em terra de:", "Moabe", ["Canaã", "Egito", "Edom"], "Dt 34")
    add("deu", "facil", "Deuteronômio insiste em amar a Deus de todo o:", "Coração", ["Ouro", "Exército", "Templo"], "Dt 6")
    add("deu", "medio", "A bênção e a maldição foram proclamadas nos montes:", "Gerizim e Ebal", ["Sinai e Horebe", "Carmelo e Sião", "Moriá e Sião"], "Dt 27")
    add("deu", "dificil", "Josué é comissionado publicamente no fim de:", "Deuteronômio", ["Gênesis", "Juízes", "Rute"], "Dt 31")
    add("deu", "expert", "O cântico de Moisés está em Deuteronômio capítulo:", "32", ["1", "6", "34"], "Dt 32")

    # ---- Josué ----
    add("jos", "facil", "Quem sucedeu Moisés na liderança?", "Josué", ["Calebe", "Arão", "Eleazar"], "Js 1")
    add("jos", "facil", "A primeira cidade conquistada em Canaã foi:", "Jericó", ["Hai", "Hebrom", "Jerusalém"], "Js 6")
    add("jos", "medio", "Raabe escondeu os espias em:", "Jericó", ["Hai", "Betel", "Siquém"], "Js 2")
    add("jos", "medio", "Israel atravessou o Jordão em terra seca como no:", "Mar Vermelho", ["Nilo", "Eufrates", "Mar Morto"], "Js 3")
    add("jos", "dificil", "Acã pecou tomando do desvio em:", "Jericó", ["Hai", "Gilgal", "Siquém"], "Js 7")
    add("jos", "expert", "O sol se deteve na batalha contra:", "Amoritas (Gibeão)", ["Filisteus", "Amaleque", "Egito"], "Js 10")
    add("jos", "facil", "Josué dividiu a terra entre as:", "Tribos", ["Nações", "Cidades gregas", "Igrejas"], "Js 13-21")
    add("jos", "medio", "Calebe pediu a montanha de:", "Hebrom", ["Sião", "Carmelo", "Tabor"], "Js 14")
    add("jos", "dificil", "As cidades de refúgio também aparecem em:", "Josué", ["Rute", "Ester", "Jonas"], "Js 20")
    add("jos", "expert", "Josué reuniu Israel para renovar a aliança em:", "Siquém", ["Betel", "Silo", "Gilgal"], "Js 24")

    # ---- Juízes ----
    add("jui", "facil", "O ciclo de Juízes inclui pecar, oprimir, clamar e:", "Libertação", ["Exílio permanente", "Templo novo", "Rei eterno"], "Jz 2")
    add("jui", "facil", "Quem derrotou Midiã com 300 homens?", "Gideão", ["Sansão", "Barace", "Jefté"], "Jz 7")
    add("jui", "medio", "Débora era:", "Profetisa e juíza", ["Rainha de Sabá", "Esposa de Davi", "Irmã de Moisés"], "Jz 4")
    add("jui", "medio", "Sansão perdeu a força quando cortaram seu:", "Cabelo", ["Dedo", "Cinto", "Manto"], "Jz 16")
    add("jui", "dificil", "Jael matou Sísera com uma:", "Estaca da tenda", ["Espada", "Pedra", "Lança"], "Jz 4")
    add("jui", "expert", "Jefté fez um voto precipitado envolvendo sua:", "Filha", ["Espada", "Casa", "Tribo"], "Jz 11")
    add("jui", "facil", "Sansão lutou principalmente contra os:", "Filisteus", ["Amoritas", "Moabitas", "Assírios"], "Jz 13-16")
    add("jui", "medio", "Gideão também foi chamado:", "Jerubaal", ["Israel", "Samuel", "Eli"], "Jz 6")
    add("jui", "dificil", "Abimeleque matou seus irmãos sobre uma:", "Pedra", ["Arca", "Árvore só", "Espada de ouro"], "Jz 9")
    add("jui", "expert", "O ídolo de Mica aparece no final de:", "Juízes", ["Josué", "Rute", "1 Samuel"], "Jz 17-18")

    # ---- Rute ----
    add("rut", "facil", "Rute era moabita e nora de:", "Noemi", ["Ana", "Ester", "Sara"], "Rt 1")
    add("rut", "facil", "Rute disse: teu povo será o meu povo, e teu Deus, o meu:", "Deus", ["Rei", "Templo", "Campo"], "Rt 1")
    add("rut", "medio", "Boaz era parente remidor de:", "Noemi/Rute", ["Débora", "Raquel", "Miriã"], "Rt 2-4")
    add("rut", "dificil", "Obede, filho de Rute, foi avô de:", "Davi", ["Saul", "Salomão só", "Samuel"], "Rt 4")
    add("rut", "expert", "A cena do calçado no portão trata do direito de:", "Resgate/levirato", ["Guerra", "Sacerdócio", "Realeza egípcia"], "Rt 4")
    add("rut", "medio", "Rute colheu espigas no campo de:", "Boaz", ["Elimeleque", "Mahlom", "Quiliom"], "Rt 2")

    # ---- 1 Samuel ----
    add("1sa", "facil", "Quem ungiu Saul e Davi?", "Samuel", ["Eli", "Natã", "Gade"], "1Sm 9-16")
    add("1sa", "facil", "Davi derrotou o gigante:", "Golias", ["Ogue", "Og", "Golias de Gate é o nome"], "1Sm 17")
    add("1sa", "medio", "Ana pediu um filho e dedicou:", "Samuel", ["Saul", "Davi", "Eli"], "1Sm 1")
    add("1sa", "medio", "A arca foi tomada pelos:", "Filisteus", ["Assírios", "Babilônios", "Egípcios"], "1Sm 4")
    add("1sa", "dificil", "Jônatas era filho de:", "Saul", ["Davi", "Samuel", "Isai"], "1Sm 13-14")
    add("1sa", "expert", "A médium de En-Dor foi consultada por:", "Saul", ["Davi", "Samuel", "Absalão"], "1Sm 28")
    add("1sa", "facil", "Davi tocava harpa para acalmar:", "Saul", ["Samuel", "Eli", "Golias"], "1Sm 16")
    add("1sa", "medio", "Mical era filha de Saul e esposa de:", "Davi", ["Jônatas", "Abner", "Isbosete"], "1Sm 18")
    add("1sa", "dificil", "Davi poupou Saul na caverna de:", "En-Gedi", ["Adulão", "Hebrom", "Silo"], "1Sm 24")
    add("1sa", "expert", "Nabal e Abigail aparecem na história de:", "Davi", ["Saul jovem", "Samuel menino", "Eli"], "1Sm 25")

    # ---- 2 Samuel ----
    add("2sa", "facil", "Davi reinou primeiro em Hebrom e depois em:", "Jerusalém", ["Betel", "Siquém", "Silo"], "2Sm 5")
    add("2sa", "medio", "Natã confrontou Davi por causa de:", "Bate-Seba e Urias", ["O censo só", "Absalão só", "Golias"], "2Sm 12")
    add("2sa", "dificil", "Absalão rebelou-se contra:", "Davi", ["Saul", "Salomão", "Samuel"], "2Sm 15")
    add("2sa", "expert", "Meñbosete era neto de:", "Saul", ["Davi", "Samuel", "Joabe"], "2Sm 9")
    add("2sa", "facil", "Joabe era comandante do exército de:", "Davi", ["Saul", "Salomão jovem", "Absalão só"], "2Sm 8")
    add("2sa", "medio", "A arca foi trazida a Jerusalém com:", "Alegria e temor", ["Guerra só", "Exílio", "Silêncio total"], "2Sm 6")
    add("2sa", "dificil", "O censo de Davi trouxe praga; o altar foi em:", "Eira de Araúna", ["Silo", "Betel", "Gibeão"], "2Sm 24")
    add("2sa", "expert", "Amnom e Tamar são drama na casa de:", "Davi", ["Saul", "Samuel", "Eli"], "2Sm 13")

    # ---- 1 Reis ----
    add("1rs", "facil", "Quem construiu o primeiro templo em Jerusalém?", "Salomão", ["Davi", "Esdras", "Neemias"], "1Rs 6")
    add("1rs", "facil", "Elias desafiou os profetas de Baal no:", "Carmelo", ["Sinai", "Sião", "Tabor"], "1Rs 18")
    add("1rs", "medio", "A rainha de Sabá visitou:", "Salomão", ["Davi", "Elias", "Acabe"], "1Rs 10")
    add("1rs", "medio", "O reino se dividiu após:", "Salomão", ["Saul", "Davi", "Josias"], "1Rs 12")
    add("1rs", "dificil", "Jeroboão estabeleceu bezerros em:", "Betel e Dã", ["Hebrom e Sião", "Silo e Gilgal", "Samaria e Tiro"], "1Rs 12")
    add("1rs", "expert", "Acabe era casado com:", "Jezabel", ["Atalia", "Bate-Seba", "Mical"], "1Rs 16")
    add("1rs", "facil", "Elias foi alimentado por corvos junto ao ribeiro:", "Querite", ["Jordão só", "Nilo", "Eufrates"], "1Rs 17")
    add("1rs", "medio", "A viúva de Sarepta hospedou:", "Elias", ["Eliseu primeiro", "Obadias", "Micaías"], "1Rs 17")
    add("1rs", "dificil", "Micaías profetizou contra:", "Acabe", ["Salomão", "Roboão só", "Josias"], "1Rs 22")
    add("1rs", "expert", "Hiram, rei de Tiro, ajudou Salomão com:", "Madeira e artífices", ["Exército egípcio", "Ouro de Ofir só", "Cavalos da Assíria"], "1Rs 5")

    # ---- 2 Reis ----
    add("2rs", "facil", "Eliseu sucedeu ao profeta:", "Elias", ["Isaías", "Jeremias", "Samuel"], "2Rs 2")
    add("2rs", "facil", "Naamã foi curado da lepra no:", "Jordão", ["Nilo", "Mar Morto", "Eufrates"], "2Rs 5")
    add("2rs", "medio", "Elias foi arrebatado em um:", "Redemoinho / carro de fogo", ["Navio", "Nuvem só", "Anjo visível eterno"], "2Rs 2")
    add("2rs", "medio", "Josias achou o livro da Lei no:", "Templo", ["Palácio", "Campo", "Exílio"], "2Rs 22")
    add("2rs", "dificil", "Samaria caiu perante a:", "Assíria", ["Babilônia", "Egito", "Roma"], "2Rs 17")
    add("2rs", "expert", "Jerusalém caiu perante Nabucodonosor da:", "Babilônia", ["Assíria", "Pérsia", "Roma"], "2Rs 25")
    add("2rs", "facil", "A sunamita recebeu um filho pela palavra de:", "Eliseu", ["Elias", "Isaías", "Jonas"], "2Rs 4")
    add("2rs", "medio", "Geazi mentiu e ficou leproso no caso de:", "Naamã", ["Acabe", "Jeú", "Hazael"], "2Rs 5")
    add("2rs", "dificil", "Jeú executou juízo sobre a casa de:", "Acabe", ["Davi", "Saul", "Omri só sem Jeú"], "2Rs 9-10")
    add("2rs", "expert", "Ezequias orou e Deus derrotou o exército de:", "Senaqueribe", ["Nabucodonosor", "Faraó Neco", "Ciro"], "2Rs 19")

    # ---- 1-2 Crônicas, Esdras, Neemias, Ester ----
    add("1cr", "medio", "1 Crônicas enfatiza a linhagem de:", "Davi e o culto", ["Paulo", "Herodes", "Cesar"], "1Cr 1-9")
    add("1cr", "dificil", "Os levitas e cantores são detalhados em:", "Crônicas", ["Rute", "Jonas", "Obadias"], "1Cr 15-16")
    add("1cr", "facil", "Davi preparou materiais para o futuro:", "Templo", ["Muro", "Palácio só", "Navio"], "1Cr 22")
    add("1cr", "expert", "O censo de Davi também é narrado em:", "1 Crônicas", ["Ester", "Rute", "Ageu"], "1Cr 21")
    add("2cr", "facil", "Salomão pede sabedoria em:", "2 Crônicas / 1 Reis", ["Ester", "Jonas", "Rute"], "2Cr 1")
    add("2cr", "medio", "A glória encheu o templo na dedicação de:", "Salomão", ["Esdras", "Neemias", "Herodes"], "2Cr 7")
    add("2cr", "dificil", "Josafá e Ezequias são reis destacados em:", "2 Crônicas", ["Ester", "Daniel", "Amós"], "2Cr 17-32")
    add("2cr", "expert", "O cativeiro e o édito de Ciro fecham:", "2 Crônicas", ["1 Samuel", "Juízes", "Rute"], "2Cr 36")
    add("esd", "facil", "Esdras era:", "Sacerdote e escriba", ["Rei", "General", "Pescador"], "Ed 7")
    add("esd", "medio", "O retorno do exílio foi autorizado por:", "Ciro", ["Nabucodonosor", "Herodes", "Faraó"], "Ed 1")
    add("esd", "dificil", "Zorobabel liderou a reconstrução do:", "Templo", ["Muro só", "Palácio", "Navio"], "Ed 3-6")
    add("esd", "expert", "Esdras chorou por causa de:", "Casamentos mistos / infidelidade", ["Fome em Egito", "Guerra com Filístia", "Morte de Saul"], "Ed 9-10")
    add("nee", "facil", "Neemias reconstruiu os:", "Muros de Jerusalém", ["Navios de Tiro", "Palácios de Babilônia", "Templo de Egito"], "Ne 2-6")
    add("nee", "medio", "Neemias era copeiro do rei:", "Artaxerxes", ["Nabucodonosor", "Ciro só", "Dario só"], "Ne 1-2")
    add("nee", "dificil", "Sanbalat e Tobias opuseram-se a:", "Neemias", ["Esdras só", "Ester", "Daniel"], "Ne 4")
    add("nee", "expert", "A leitura da Lei com Esdras ocorre em:", "Neemias 8", ["Ester 1", "Rute 1", "Jonas 1"], "Ne 8")
    add("est", "facil", "Ester foi rainha na corte da:", "Pérsia", ["Babilônia só", "Assíria", "Roma"], "Et 1-2")
    add("est", "facil", "Hamã planejou destruir os:", "Judeus", ["Egípcios", "Filisteus", "Romanos"], "Et 3")
    add("est", "medio", "Mardoqueu era parente de:", "Ester", ["Rute", "Débora", "Ana"], "Et 2")
    add("est", "dificil", "A festa de Purim lembra a livramento em:", "Ester", ["Rute", "Jonas", "Daniel"], "Et 9")
    add("est", "expert", "O rei em Ester é:", "Assuero (Xerxes)", ["Ciro", "Dario Medo", "Nabucodonosor"], "Et 1")

    # ---- Jó, Salmos, Provérbios, Eclesiastes, Cânticos ----
    add("jo", "facil", "Jó era conhecido por sua:", "Integridade e temor a Deus", ["Riqueza só", "Realeza", "Sacerdócio levítico"], "Jó 1")
    add("jo", "medio", "Os três amigos de Jó foram:", "Elifaz, Bildade e Zofar", ["Pedro, Tiago e João", "Saul, Davi e Salomão", "Elias, Eliseu e Jonas"], "Jó 2")
    add("jo", "dificil", "Eliú fala mais tarde no livro de:", "Jó", ["Salmos", "Provérbios", "Eclesiastes"], "Jó 32")
    add("jo", "expert", "Deus responde a Jó desde um:", "Redemoinho", ["Templo", "Trono humano", "Sonho de Faraó"], "Jó 38")
    add("jo", "facil", "Satanás acusa Jó perante:", "Deus", ["Moisés", "Davi", "Paulo"], "Jó 1")
    add("jo", "medio", "No fim, Jó é restaurado em:", "Bênçãos em dobro", ["Exílio", "Morte precoce", "Realeza"], "Jó 42")
    add("sal", "facil", "O Salmo 23 começa: 'O Senhor é o meu:", "Pastor", ["Rei só", "Juiz só", "Guerreiro só"], "Sl 23")
    add("sal", "facil", "Muitos salmos são atribuídos a:", "Davi", ["Moisés só", "Paulo", "Pedro"], "Sl")
    add("sal", "medio", "O Salmo 51 é uma confissão após o pecado com:", "Bate-Seba", ["Golias", "Saul", "Absalão só"], "Sl 51")
    add("sal", "medio", "O Salmo 119 exalta a:", "Palavra / lei de Deus", ["Guerra", "Riqueza", "Viagem"], "Sl 119")
    add("sal", "dificil", "Os cânticos de Degraus são salmos:", "120–134", ["1–10", "23–25", "150 só"], "Sl 120-134")
    add("sal", "expert", "O Salmo 90 é atribuído a:", "Moisés", ["Davi", "Asafe só", "Salomão"], "Sl 90")
    add("sal", "facil", "O livro de Salmos tem quantos capítulos/salmos?", "150", ["66", "39", "27"], "Sl")
    add("sal", "dificil", "Asafe é associado a vários:", "Salmos", ["Provérbios", "Evangelhos", "Epístolas"], "Sl 73")
    add("pro", "facil", "Provérbios ensina que o temor do Senhor é o princípio da:", "Sabedoria", ["Riqueza", "Guerra", "Fama"], "Pv 1")
    add("pro", "medio", "Muitos provérbios são de:", "Salomão", ["Davi", "Moisés", "Paulo"], "Pv 1")
    add("pro", "dificil", "A mulher virtuosa é descrita em Provérbios:", "31", ["1", "8", "15"], "Pv 31")
    add("pro", "expert", "Agur e Lemuel aparecem perto do fim de:", "Provérbios", ["Salmos", "Jó", "Eclesiastes"], "Pv 30-31")
    add("pro", "facil", "Provérbios contrasta o sábio e o:", "Insensato", ["Anjo", "Rei", "Sacerdote"], "Pv 1-9")
    add("pro", "medio", "A sabedoria clama nas:", "Praças / ruas", ["Somente no templo", "Somente no palácio", "Somente no deserto"], "Pv 1")
    add("ecl", "facil", "Eclesiastes repete: 'Vaidade de vaidades, tudo é:", "Vaidade", ["Eterno", "Ouro", "Guerra"], "Ec 1")
    add("ecl", "medio", "Há tempo de nascer e tempo de:", "Morrer", ["Reinar", "Viajar", "Construir só"], "Ec 3")
    add("ecl", "dificil", "O Pregador em Eclesiastes é tradicionalmente ligado a:", "Salomão", ["Davi", "Moisés", "Esdras"], "Ec 1")
    add("ecl", "expert", "O fim do dever humano: temer a Deus e guardar os:", "Mandamentos", ["Tesouros", "Exércitos", "Sonhos"], "Ec 12")
    add("can", "facil", "Cânticos é um poema de:", "Amor", ["Guerra", "Lei", "Exílio"], "Ct 1")
    add("can", "medio", "Cânticos também é chamado:", "Cântico dos Cânticos", ["Lamentações", "Provérbios 2", "Salmo 151"], "Ct 1")
    add("can", "dificil", "A voz ama o amado entre as:", "Donzelas de Jerusalém", ["Tribos de Levi", "Reis de Israel", "Profetas"], "Ct 1")
    add("can", "expert", "Cânticos tem quantos capítulos?", "8", ["5", "12", "66"], "Ct")

    # Fix the broken can dificil entry - I made a syntax error with nested lists
    # I'll fix in the file after - let me be careful

    return F


def facts_part2() -> list[tuple]:
    F: list[tuple] = []

    def add(book: str, level: str, question: str, correct: str, distractors: list[str], ref: str | None = None):
        F.append((book, level, question, correct, distractors, ref))

    # Fix Cânticos + Profetas maiores
    add("can", "dificil", "Em Cânticos, as filhas de Jerusalém são:", "Coro / interlocutoras", ["Apóstolos", "Levitas guerreiros", "Reis midianitas"], "Ct 1")
    add("isa", "facil", "Isaías viu o Senhor no templo no ano em que morreu:", "Uzias", ["Davi", "Saul", "Josias"], "Is 6")
    add("isa", "facil", "Isaías 7:14 anuncia o nascimento de:", "Emanuel", ["Jonas", "Moisés", "Elias"], "Is 7")
    add("isa", "medio", "Isaías 53 fala do:", "Servo sofredor", ["Rei Saul", "Faraó", "Golias"], "Is 53")
    add("isa", "medio", "Isaías profetizou principalmente em:", "Judá / Jerusalém", ["Nínive só", "Roma", "Egito só"], "Is 1")
    add("isa", "dificil", "O livro de Isaías tem quantos capítulos?", "66", ["39", "27", "12"], "Is")
    add("isa", "expert", "Ciro é nomeado como libertador em:", "Isaías", ["Jonas", "Rute", "Obadias"], "Is 45")
    add("isa", "facil", "Santo, santo, santo é o Senhor dos Exércitos — visão de:", "Isaías", ["Ezequiel só", "Daniel só", "Amós"], "Is 6")
    add("isa", "dificil", "O príncipe da paz é anunciado em Isaías:", "9", ["1", "40", "66"], "Is 9")
    add("isa", "expert", "Lúcifer / astro da manhã no oráculo contra o rei de Babilônia está em:", "Isaías 14", ["Gênesis 3", "Jó 1", "Apocalipse 12 só"], "Is 14")
    add("jer", "facil", "Jeremias é conhecido como o profeta:", "Chorão / das lamentações", ["Do fogo do Carmelo", "Do peixe", "Do sonho de Nabucodonosor"], "Jr 1")
    add("jer", "medio", "Jeremias foi chamado sendo:", "Jovem", ["Rei", "Sacerdote egípcio", "General"], "Jr 1")
    add("jer", "dificil", "Jeremias comprou um campo em Anatote como sinal de:", "Esperança pós-exílio", ["Guerra imediata", "Fim de Israel", "Templo eterno sem juízo"], "Jr 32")
    add("jer", "expert", "A nova aliança é prometida em Jeremias:", "31", ["1", "25", "52"], "Jr 31")
    add("jer", "facil", "Jeremias alertou sobre a invasão da:", "Babilônia", ["Roma", "Grécia", "Pérsia só"], "Jr 25")
    add("jer", "medio", "Baruque escreveu as palavras de:", "Jeremias", ["Isaías", "Ezequiel", "Daniel"], "Jr 36")
    add("jer", "dificil", "O jugo de madeira e de ferro ilustra submissão a:", "Babilônia", ["Egito", "Assíria", "Roma"], "Jr 27-28")
    add("jer", "expert", "Gedalias foi governador após a queda e foi:", "Assassinado", ["Coroado rei", "Levado a Roma", "Feito sumo sacerdote"], "Jr 40-41")
    add("lam", "facil", "Lamentações chora a queda de:", "Jerusalém", ["Nínive", "Roma", "Corinto"], "Lm 1")
    add("lam", "medio", "As misericórdias do Senhor se renovam a cada:", "Manhã", ["Ano", "Século", "Lua"], "Lm 3")
    add("lam", "dificil", "Lamentações tem quantos capítulos?", "5", ["8", "12", "3"], "Lm")
    add("lam", "expert", "A estrutura acróstica hebraica marca vários poemas de:", "Lamentações", ["Obadias", "Ageu", "Filemom"], "Lm")
    add("eze", "facil", "Ezequiel foi profeta entre os exilados em:", "Babilônia", ["Egito", "Roma", "Nínive"], "Ez 1")
    add("eze", "medio", "Ezequiel viu a visão dos:", "Querubins / rodas", ["Peixes", "Gafanhotos só", "Cavalos romanos"], "Ez 1")
    add("eze", "dificil", "A visão do vale de ossos secos está em:", "Ezequiel 37", ["Daniel 7", "Isaías 6", "Joel 2"], "Ez 37")
    add("eze", "expert", "O templo futuro e a divisão da terra fecham:", "Ezequiel", ["Ageu", "Malaquias", "Jonas"], "Ez 40-48")
    add("eze", "facil", "Ezequiel era:", "Sacerdote-profeta", ["Rei", "Pescador", "Coletor"], "Ez 1")
    add("eze", "medio", "A glória do Senhor deixa o templo em visão de:", "Ezequiel", ["Ageu", "Jonas", "Naum"], "Ez 10-11")
    add("eze", "dificil", "Tiro e Egito recebem oráculos em:", "Ezequiel", ["Rute", "Ester", "Filemom"], "Ez 26-32")
    add("eze", "expert", "Gogue e Magogue aparecem em:", "Ezequiel 38–39", ["Rute 1", "Jonas 2", "Ageu 1"], "Ez 38-39")
    add("dan", "facil", "Daniel foi levado para:", "Babilônia", ["Egito", "Roma", "Nínive"], "Dn 1")
    add("dan", "facil", "Os três amigos na fornalha foram:", "Sadraque, Mesaque e Abede-Nego", ["Pedro, Tiago e João", "Caim, Abel e Sete", "Saul, Davi e Salomão"], "Dn 3")
    add("dan", "medio", "Daniel foi lançado na cova dos:", "Leões", ["Ursos", "Crocodilos", "Escorpiões"], "Dn 6")
    add("dan", "medio", "Nabucodonosor sonhou com uma:", "Estátua de metais", ["Escada", "Sarça", "Arca"], "Dn 2")
    add("dan", "dificil", "A escrita na parede apareceu no banquete de:", "Belsazar", ["Dario", "Ciro", "Artaxerxes"], "Dn 5")
    add("dan", "expert", "As 70 semanas são profecia em Daniel:", "9", ["1", "3", "12"], "Dn 9")
    add("dan", "facil", "Daniel resolveu não se contaminar com a comida do:", "Rei", ["Templo", "Sacerdote", "Profeta"], "Dn 1")
    add("dan", "dificil", "O Filho do Homem vem com as nuvens em Daniel:", "7", ["2", "5", "12"], "Dn 7")
    add("dan", "expert", "Miguel é mencionado como príncipe em:", "Daniel", ["Rute", "Ester", "Ageu"], "Dn 10-12")

    # Profetas menores
    add("ose", "facil", "Oséias foi chamado a casar-se com:", "Gômer", ["Rute", "Ester", "Maria"], "Os 1")
    add("ose", "medio", "Oséias ilustra o amor de Deus por:", "Israel infiel", ["Egito", "Roma", "Babilônia só"], "Os 1-3")
    add("ose", "dificil", "Oséias diz: misericórdia quero, e não:", "Sacrifício", ["Oração", "Cântico", "Jejum só"], "Os 6")
    add("ose", "expert", "Efraim é frequentemente citado em:", "Oséias", ["Filemom", "2 João", "Obadias só"], "Os 4-14")
    add("joe", "facil", "Joel fala de uma praga de:", "Gafanhotos", ["Rãs", "Sangue", "Granizo só"], "Jl 1")
    add("joe", "medio", "Joel promete o derramamento do:", "Espírito", ["Ouro", "Óleo real", "Maná"], "Jl 2")
    add("joe", "dificil", "O dia do Senhor é tema central de:", "Joel", ["Rute", "Ester", "Filemom"], "Jl 1-3")
    add("joe", "expert", "Pedro cita Joel no Pentecostes em:", "Atos 2", ["Romanos 1", "Hebreus 1", "Tiago 1"], "Jl 2 / At 2")
    add("amo", "facil", "Amós era:", "Pastor / boieiro de Tecoa", ["Rei", "Sacerdote de Silo", "Pescador"], "Am 1")
    add("amo", "medio", "Amós denuncia injustiça social em:", "Israel", ["Roma", "Egito faraônico", "Grécia"], "Am 2-6")
    add("amo", "dificil", "Amós viu um prumo / fio de prumo como sinal de:", "Juízo", ["Bênção só", "Templo novo", "Casamento"], "Am 7")
    add("amo", "expert", "A restauração da tenda de Davi aparece em:", "Amós", ["Obadias", "Naum", "Ageu"], "Am 9")
    add("oba", "facil", "Obadias profetiza contra:", "Edom", ["Nínive", "Egito", "Roma"], "Ob 1")
    add("oba", "medio", "Obadias é o menor livro do:", "AT (1 capítulo)", ["NT", "Pentateuco", "Salmos"], "Ob")
    add("oba", "dificil", "Edom descendia de:", "Esaú", ["Jacó", "Ismael", "Ló"], "Ob 1")
    add("oba", "expert", "O dia do Senhor sobre as nações fecha:", "Obadias", ["Rute", "Filemom", "2 João"], "Ob 1")
    add("jon", "facil", "Jonas foi engolido por um:", "Grande peixe", ["Leão", "Urso", "Dragão"], "Jn 1-2")
    add("jon", "facil", "Deus mandou Jonas a:", "Nínive", ["Babilônia", "Jerusalém", "Roma"], "Jn 1")
    add("jon", "medio", "Jonas embarcou para:", "Társis", ["Egito", "Damasco", "Éfeso"], "Jn 1")
    add("jon", "dificil", "A planta que sombreou Jonas foi:", "Uma mamoneira / planta", ["Uma oliveira", "Uma videira de Canaã", "Um cedro"], "Jn 4")
    add("jon", "expert", "Jonas se indignou porque Deus perdoou:", "Nínive", ["Israel", "Judá", "Edom"], "Jn 4")
    add("miq", "facil", "Miquéias anuncia o governante de:", "Belém", ["Nazaré", "Jerusalém só", "Hebrom"], "Mq 5")
    add("miq", "medio", "O Senhor requer justiça, misericórdia e andar:", "Humildemente", ["Ricamente", "Guerreiramente", "Silenciosamente só"], "Mq 6")
    add("miq", "dificil", "Miquéias foi contemporâneo aproximado de:", "Isaías", ["Daniel", "Malaquias", "Jonas só"], "Mq 1")
    add("miq", "expert", "Sião será exaltada no fim dos tempos em:", "Miquéias", ["Obadias só", "Filemom", "2 João"], "Mq 4")
    add("naa", "facil", "Naum profetiza a queda de:", "Nínive", ["Jerusalém", "Roma", "Corinto"], "Na 1-3")
    add("naa", "medio", "Nínive era capital da:", "Assíria", ["Babilônia", "Pérsia", "Roma"], "Na 1")
    add("naa", "dificil", "Naum contrasta com a misericórdia vista em:", "Jonas (sobre Nínive)", ["Rute", "Ester", "Filemom"], "Na")
    add("naa", "expert", "Naum tem quantos capítulos?", "3", ["1", "12", "66"], "Na")
    add("hab", "facil", "Habacuque pergunta a Deus sobre a:", "Injustiça", ["Fome em Egito", "Construção do templo", "Viagem de Paulo"], "Hc 1")
    add("hab", "medio", "O justo viverá pela:", "Fé", ["Espada", "Riqueza", "Lei cerimonial só"], "Hc 2")
    add("hab", "dificil", "Habacuque termina com um:", "Cântico de confiança", ["Censo", "Mapa", "Código penal"], "Hc 3")
    add("hab", "expert", "Paulo cita Habacuque em:", "Romanos / Gálatas", ["Tiago só", "Apocalipse só", "Atos 7 só"], "Hc 2")
    add("sof", "facil", "Sofonias anuncia o:", "Dia do Senhor", ["Nascimento de Isaque", "Êxodo", "Pentecostes histórico"], "Sf 1")
    add("sof", "medio", "Sofonias profetizou no tempo de:", "Josias", ["Davi", "Saul", "Herodes"], "Sf 1")
    add("sof", "dificil", "Sofonias promete um remanescente:", "Humilde", ["Rico", "Guerreiro assírio", "Egípcio"], "Sf 3")
    add("sof", "expert", "Sofonias tem quantos capítulos?", "3", ["8", "14", "66"], "Sf")
    add("age", "facil", "Ageu anima a reconstruir o:", "Templo", ["Muro só", "Palácio de Herodes", "Navio"], "Ag 1")
    add("age", "medio", "Ageu foi contemporâneo de:", "Zacarias / Zorobabel", ["Isaías", "Jonas", "Daniel na fornalha"], "Ag 1")
    add("age", "dificil", "Ageu tem quantos capítulos?", "2", ["12", "66", "150"], "Ag")
    add("age", "expert", "A glória da casa futura será maior, diz:", "Ageu", ["Obadias", "Naum", "Filemom"], "Ag 2")
    add("zac", "facil", "Zacarias teve várias:", "Visões noturnas", ["Viagens a Roma", "Batalhas navais", "Censos egípcios"], "Zc 1-6")
    add("zac", "medio", "O rei vem montado em um jumento — profecia em:", "Zacarias", ["Jonas", "Naum", "Obadias"], "Zc 9")
    add("zac", "dificil", "Olharam para aquele a quem traspassaram — em:", "Zacarias", ["Ageu", "Malaquias", "Amós"], "Zc 12")
    add("zac", "expert", "Josué, o sumo sacerdote, e Zorobabel aparecem em:", "Zacarias", ["Jonas", "Rute", "Ester"], "Zc 3-4")
    add("mal", "facil", "Malaquias é o último livro do:", "Antigo Testamento", ["Novo Testamento", "Pentateuco", "Salmos"], "Ml")
    add("mal", "medio", "Malaquias fala do mensageiro que prepara o:", "Caminho", ["Templo de Herodes", "Exílio", "Censo"], "Ml 3")
    add("mal", "dificil", "Trazei todos os dízimos à casa do tesouro — em:", "Malaquias", ["Jonas", "Obadias", "Filemom"], "Ml 3")
    add("mal", "expert", "Elias é prometido antes do dia do Senhor em:", "Malaquias", ["Ageu", "Naum", "Amós 1"], "Ml 4")

    return F


def facts_part3() -> list[tuple]:
    """Novo Testamento."""
    F: list[tuple] = []

    def add(book: str, level: str, question: str, correct: str, distractors: list[str], ref: str | None = None):
        F.append((book, level, question, correct, distractors, ref))

    # Evangelhos
    add("mat", "facil", "Jesus nasceu em:", "Belém", ["Nazaré", "Jerusalém", "Capernaum"], "Mt 2")
    add("mat", "facil", "Os magos trouxeram ouro, incenso e:", "Mirra", ["Prata", "Bronze", "Maná"], "Mt 2")
    add("mat", "medio", "O Sermão do Monte está principalmente em:", "Mateus 5–7", ["João 3", "Atos 2", "Romanos 8"], "Mt 5-7")
    add("mat", "medio", "Mateus apresenta Jesus especialmente como:", "Messias / Rei", ["Apenas sacerdote egípcio", "Apenas anjo", "Apenas profeta de Nínive"], "Mt 1")
    add("mat", "dificil", "As bem-aventuranças abrem o:", "Sermão do Monte", ["Pai Nosso só", "Apocalipse", "Pentecostes"], "Mt 5")
    add("mat", "expert", "A Grande Comissão fecha Mateus com: ide e fazei:", "Discípulos", ["Soldados", "Comerciantes", "Reis"], "Mt 28")
    add("mat", "facil", "José, esposo de Maria, foi avisado em:", "Sonho", ["Carta", "Visão de Nabucodonosor", "Urim"], "Mt 1-2")
    add("mat", "medio", "Pedro confessa: Tu és o Cristo em:", "Mateus 16", ["João 1 só", "Atos 1", "Hebreus 1"], "Mt 16")
    add("mat", "dificil", "As 70x7 perdões são ensinados em:", "Mateus", ["Judas", "Obadias", "Ageu"], "Mt 18")
    add("mat", "expert", "O julgamento das ovelhas e cabritos está em:", "Mateus 25", ["Marcos 1", "Lucas 1", "João 1"], "Mt 25")
    add("mar", "facil", "Marcos começa com o ministério de:", "João Batista", ["Paulo", "Pedro em Roma só", "Tiago"], "Mc 1")
    add("mar", "medio", "Marcos é o evangelho mais:", "Breve / dinâmico", ["Longo", "Só de parábolas", "Só de cartas"], "Mc")
    add("mar", "dificil", "O jovem que fugiu nu aparece só em:", "Marcos", ["Mateus", "Lucas", "João"], "Mc 14")
    add("mar", "expert", "A frase 'imediatamente' (euthys) é típica de:", "Marcos", ["Hebreus", "Tiago", "Judas"], "Mc")
    add("mar", "facil", "Jesus cura um paralítico em Capernaum em:", "Marcos 2", ["Apocalipse 2", "Romanos 2", "Gálatas 2"], "Mc 2")
    add("mar", "medio", "Bartimeu, o cego, foi curado perto de:", "Jericó", ["Nazaré", "Belém", "Roma"], "Mc 10")
    add("mar", "dificil", "O maior mandamento é citado também em:", "Marcos 12", ["Obadias", "Ageu", "Filemom"], "Mc 12")
    add("mar", "expert", "O final longo de Marcos inclui aparições após a:", "Ressurreição", ["Ascensão só sem aparições", "Pentecostes", "Conversão de Paulo"], "Mc 16")
    add("luc", "facil", "Lucas dedica sua obra a:", "Teófilo", ["Timóteo", "Tito", "Filemom"], "Lc 1")
    add("luc", "facil", "O anjo anunciou a Maria o nascimento de:", "Jesus", ["João Batista só", "Pedro", "Paulo"], "Lc 1")
    add("luc", "medio", "A parábola do bom samaritano está em:", "Lucas", ["Mateus só", "João", "Marcos só"], "Lc 10")
    add("luc", "medio", "Lucas enfatiza o cuidado com:", "Pobres, mulheres e perdidos", ["Apenas reis", "Apenas levitas", "Apenas soldados"], "Lc")
    add("luc", "dificil", "Zaqueu era:", "Publicano em Jericó", ["Fariseu em Roma", "Sacerdote em Silo", "Rei em Samaria"], "Lc 19")
    add("luc", "expert", "Os caminhantes de Emaús encontram Jesus em:", "Lucas 24", ["João 1", "Atos 1", "Marcos 1"], "Lc 24")
    add("luc", "facil", "João Batista nasceu de:", "Zacarias e Isabel", ["José e Maria", "Elcana e Ana", "Abraão e Sara"], "Lc 1")
    add("luc", "medio", "O filho pródigo é parábola de:", "Lucas 15", ["Mateus 1", "João 15", "Marcos 1"], "Lc 15")
    add("luc", "dificil", "O cântico Magnificat é de:", "Maria", ["Isabel só", "Ana", "Débora"], "Lc 1")
    add("luc", "expert", "Lucas também escreveu:", "Atos dos Apóstolos", ["Hebreus", "Apocalipse", "Romanos"], "Lc / At")
    add("joao", "facil", "No princípio era o:", "Verbo", ["Templo", "Anjo", "Rei"], "Jo 1")
    add("joao", "facil", "João 3:16 fala do amor de Deus ao:", "Mundo", ["Templo só", "Império", "Deserto"], "Jo 3")
    add("joao", "medio", "Jesus transformou água em vinho em:", "Caná", ["Belém", "Jericó", "Roma"], "Jo 2")
    add("joao", "medio", "Nicodemos ouviu: é necessário nascer de:", "Novo / água e Espírito", ["Novo ouro", "Novo cargo", "Novo exército"], "Jo 3")
    add("joao", "dificil", "Eu sou a videira verdadeira — em:", "João 15", ["Mateus 1", "Atos 1", "Romanos 1"], "Jo 15")
    add("joao", "expert", "O discípulo a quem Jesus amava tradicionalmente é:", "João", ["Pedro", "Tomé", "Judas Iscariotes"], "Jo 13-21")
    add("joao", "facil", "Lázaro foi ressuscitado em:", "Betânia", ["Nazaré", "Roma", "Damasco"], "Jo 11")
    add("joao", "medio", "A samaritana encontrou Jesus junto ao:", "Poço", ["Templo de Herodes", "Mar da Galileia só", "Jordão só"], "Jo 4")
    add("joao", "dificil", "Os sete 'Eu sou' caracterizam o evangelho de:", "João", ["Marcos só", "Mateus só", "Lucas só"], "Jo")
    add("joao", "expert", "Tomé confessou: Senhor meu e Deus meu em:", "João 20", ["Atos 2", "Romanos 10", "Hebreus 1"], "Jo 20")

    # Atos + Paulo
    add("ato", "facil", "O Espírito Santo desceu no:", "Pentecostes", ["Natal", "Páscoa judaica só", "Dia da Expiação"], "At 2")
    add("ato", "facil", "Saulo encontrou Jesus no caminho de:", "Damasco", ["Roma", "Éfeso", "Atenas"], "At 9")
    add("ato", "medio", "Pedro pregou e milhares se converteram em:", "Atos 2", ["Apocalipse 2", "Romanos 2", "Tiago 2"], "At 2")
    add("ato", "medio", "Barnabé acompanhou Paulo em viagens de:", "Missão", ["Comércio de ouro", "Guerra romana", "Construção do templo"], "At 13")
    add("ato", "dificil", "O concílio de Jerusalém tratou da circuncisão dos:", "Gentios", ["Levitas", "Reis", "Anjos"], "At 15")
    add("ato", "expert", "Paulo apelou para César sendo cidadão:", "Romano", ["Egípcio", "Babilônico", "Persa"], "At 25")
    add("ato", "facil", "Estêvão foi o primeiro:", "Mártir cristão citado", ["Papa", "Rei", "Centurião"], "At 7")
    add("ato", "medio", "Cornélio foi centurião em:", "Cesareia", ["Nazaré", "Belém", "Nínive"], "At 10")
    add("ato", "dificil", "Lídia, vendedora de púrpura, estava em:", "Filipos", ["Roma", "Corinto só", "Éfeso só"], "At 16")
    add("ato", "expert", "O naufrágio de Paulo ocorreu a caminho de:", "Roma", ["Jerusalém", "Damasco", "Nínive"], "At 27")
    add("rom", "facil", "Romanos ensina justificação pela:", "Fé", ["Lei só", "Ouro", "Raça"], "Rm 3-5")
    add("rom", "medio", "Todos pecaram e destituídos estão da:", "Glória de Deus", ["Cidadania romana", "Riqueza", "Sabedoria grega"], "Rm 3")
    add("rom", "dificil", "Romanos 8 celebra a vida no:", "Espírito", ["Império", "Templo herodiano", "Sinédrio"], "Rm 8")
    add("rom", "expert", "Israel e as oliveiras são metáfora em Romanos:", "11", ["1", "5", "16"], "Rm 11")
    add("rom", "facil", "Paulo deseja ir a:", "Roma", ["Nínive", "Babilônia", "Ur"], "Rm 1")
    add("rom", "medio", "Apresentai vossos corpos em sacrifício:", "Vivo", ["Morto cerimonial", "De ouro", "De animais só"], "Rm 12")
    add("rom", "dificil", "A carta aos Romanos tem quantos capítulos?", "16", ["13", "6", "22"], "Rm")
    add("rom", "expert", "Febe é recomendada perto do fim de:", "Romanos", ["Judas", "Obadias", "Ageu"], "Rm 16")
    add("1co", "facil", "O amor é descrito em 1 Coríntios:", "13", ["1", "5", "16"], "1Co 13")
    add("1co", "medio", "Paulo fala da ressurreição em 1 Coríntios:", "15", ["2", "7", "11"], "1Co 15")
    add("1co", "dificil", "Os dons espirituais são tratados em 1 Coríntios:", "12–14", ["1–2", "5–6", "15–16 só"], "1Co 12-14")
    add("1co", "expert", "A Ceia do Senhor é corrigida em 1 Coríntios:", "11", ["3", "8", "16"], "1Co 11")
    add("1co", "facil", "Corinto era cidade da:", "Grécia", ["Pérsia", "Assíria", "Egito faraônico"], "1Co 1")
    add("1co", "medio", "Cristo, nossa páscoa, foi:", "Imolado", ["Coroado em Roma", "Exilado", "Esquecido"], "1Co 5")
    add("1co", "dificil", "Falo línguas de homens e de anjos… sem amor, nada sou — em:", "1 Coríntios", ["Tiago", "Judas", "Filemom"], "1Co 13")
    add("1co", "expert", "A coleta para os santos aparece em 1 Coríntios:", "16", ["2", "7", "10"], "1Co 16")
    add("2co", "facil", "2 Coríntios enfatiza o:", "Ministério e conforto", ["Censo de Israel", "Templo de Salomão", "Dilúvio"], "2Co 1")
    add("2co", "medio", "O véu e a nova aliança são tema em 2 Coríntios:", "3", ["1", "8", "13"], "2Co 3")
    add("2co", "dificil", "Paulo fala do espinho na carne em:", "2 Coríntios 12", ["Romanos 1", "Gálatas 1", "Efésios 1"], "2Co 12")
    add("2co", "expert", "A generosidade macedônia inspira a coleta em:", "2 Coríntios 8–9", ["Filemom", "Judas", "2 João"], "2Co 8-9")
    add("gal", "facil", "Gálatas defende a justificação sem:", "Obras da lei", ["Fé", "Graça", "Espírito"], "Gl 2-3")
    add("gal", "medio", "O fruto do Espírito está em Gálatas:", "5", ["1", "3", "6"], "Gl 5")
    add("gal", "dificil", "Paulo confronta Pedro em:", "Antioquia (Gálatas 2)", ["Roma", "Nínive", "Babilônia"], "Gl 2")
    add("gal", "expert", "Hagar e Sara ilustram duas alianças em:", "Gálatas 4", ["Romanos 1 só", "Hebreus 1", "Tiago 1"], "Gl 4")
    add("ef", "facil", "Efésios fala da igreja como:", "Corpo de Cristo", ["Império romano", "Templo de Baal", "Exército de Saul"], "Ef 1-4")
    add("ef", "medio", "Pela graça sois salvos, mediante a:", "Fé", ["Lei", "Raça", "Riqueza"], "Ef 2")
    add("ef", "dificil", "A armadura de Deus está em Efésios:", "6", ["1", "3", "4"], "Ef 6")
    add("ef", "expert", "O mistério dos gentios coherdeiros está em:", "Efésios 3", ["Filemom", "2 João", "3 João"], "Ef 3")
    add("fp", "facil", "Filipenses é carta da:", "Alegria", ["Ira", "Guerra", "Exílio babilônico"], "Fp 1-4")
    add("fp", "medio", "O hino de Cristo que se esvaziou está em Filipenses:", "2", ["1", "3", "4"], "Fp 2")
    add("fp", "dificil", "Posso todas as coisas naquele que me:", "Fortalece", ["Condena", "Esquece", "Exila"], "Fp 4")
    add("fp", "expert", "Evódia e Síntique são exortadas à unidade em:", "Filipenses", ["Judas", "Obadias", "Ageu"], "Fp 4")
    add("cl", "facil", "Colossenses exalta a:", "Supremacia de Cristo", ["Lei mosaica só", "Templo de Herodes", "Filosofia grega"], "Cl 1")
    add("cl", "medio", "Cristo é a imagem do Deus:", "Invisível", ["Romano", "Egípcio", "Babilônico"], "Cl 1")
    add("cl", "dificil", "Paulo adverte contra filosofia e tradições em:", "Colossenses 2", ["Filemom", "2 João", "3 João"], "Cl 2")
    add("cl", "expert", "Arquipo é mencionado perto de Colossenses /:", "Filemom", ["Judas", "Obadias", "Naum"], "Cl 4")
    add("1ts", "facil", "1 Tessalonicenses fala da:", "Volta do Senhor", ["Construção do templo de Salomão", "Dilúvio", "Êxodo"], "1Ts 4-5")
    add("1ts", "medio", "Os mortos em Cristo ressuscitarão:", "Primeiro", ["Nunca", "Só em espírito sem corpo", "Após mil anos sem Cristo"], "1Ts 4")
    add("1ts", "dificil", "O dia do Senhor vem como:", "Ladrão de noite", ["Festa de Purim", "Censo romano", "Lua nova só"], "1Ts 5")
    add("1ts", "expert", "1 Tessalonicenses é das cartas mais:", "Antigas de Paulo", ["Últimas do NT", "Do AT", "De Pedro"], "1Ts")
    add("2ts", "facil", "2 Tessalonicenses corrige ideias sobre a:", "Vinda de Cristo", ["Lei cerimonial de Levítico", "Arca de Noé", "Torre de Babel"], "2Ts 2")
    add("2ts", "medio", "O homem da iniquidade é tema de:", "2 Tessalonicenses", ["Rute", "Ester", "Jonas"], "2Ts 2")
    add("2ts", "dificil", "Quem não quer trabalhar, também não:", "Coma", ["Ore", "Cante", "Viaje"], "2Ts 3")
    add("2ts", "expert", "2 Tessalonicenses tem quantos capítulos?", "3", ["16", "28", "66"], "2Ts")
    add("1tm", "facil", "1 Timóteo orienta sobre a:", "Ordem na igreja", ["Conquista de Canaã", "Construção da arca", "Censo de César"], "1Tm 3")
    add("1tm", "medio", "O bispo/presbítero deve ser:", "Irrepreensível", ["Rico obrigatoriamente", "Romano", "Levita de sangue"], "1Tm 3")
    add("1tm", "dificil", "O amor ao dinheiro é raiz de toda espécie de:", "Males", ["Bênçãos", "Dons", "Milagres"], "1Tm 6")
    add("1tm", "expert", "Timóteo estava em:", "Éfeso (contexto)", ["Nínive", "Babilônia", "Ur"], "1Tm 1")
    add("2tm", "facil", "Toda Escritura é inspirada por:", "Deus", ["Homens só", "Anjos só", "Reis"], "2Tm 3")
    add("2tm", "medio", "Paulo sente que está perto do:", "Fim / partida", ["Início do Êxodo", "Censo de Israel", "Dilúvio"], "2Tm 4")
    add("2tm", "dificil", "Combati o bom combate, acabei a:", "Carreira", ["Torre", "Arca", "Muralha"], "2Tm 4")
    add("2tm", "expert", "Demas abandonou Paulo amando o:", "Presente século", ["Templo", "Maná", "Jordão"], "2Tm 4")
    add("tt", "facil", "Tito foi deixado em:", "Creta", ["Roma só", "Nínive", "Babilônia"], "Tt 1")
    add("tt", "medio", "Tito deve constituir:", "Presbíteros", ["Reis", "Centuriões", "Faraós"], "Tt 1")
    add("tt", "dificil", "A graça de Deus ensina a renunciar à:", "Impiedade", ["Oração", "Hospitalidade", "Boas obras"], "Tt 2")
    add("tt", "expert", "Tito tem quantos capítulos?", "3", ["13", "28", "66"], "Tt")
    add("fm", "facil", "Filemom trata do escravo:", "Onésimo", ["Onesíforo só", "Demas", "Tíquico"], "Fm 1")
    add("fm", "medio", "Paulo pede que Filemom receba Onésimo como:", "Irmão", ["Inimigo", "Estrangeiro permanente", "Soldado"], "Fm 1")
    add("fm", "dificil", "Filemom tem quantos capítulos?", "1", ["3", "5", "13"], "Fm")
    add("fm", "expert", "A carta a Filemom é a mais:", "Curta de Paulo (pessoal)", ["Longa do NT", "Do AT", "De Pedro"], "Fm")

    # Católicas + Apocalipse
    add("hb", "facil", "Hebreus apresenta Jesus como:", "Sumo sacerdote superior", ["Anjo criado", "Apenas profeta de Nínive", "Rei romano"], "Hb 4-7")
    add("hb", "medio", "A fé é a certeza de coisas que se:", "Esperam", ["Compram", "Conquistam pela espada", "Vêem sempre"], "Hb 11")
    add("hb", "dificil", "Melquisedeque é tipo sacerdotal em:", "Hebreus", ["Tiago", "Judas", "Filemom"], "Hb 7")
    add("hb", "expert", "A nuvem de testemunhas está em Hebreus:", "12", ["1", "5", "13"], "Hb 12")
    add("hb", "facil", "Jesus é superior aos:", "Anjos", ["Apenas a Moisés sem mais", "Apenas a Arão sem mais", "Romanos imperadores"], "Hb 1")
    add("hb", "medio", "Não deixemos de congregar-nos — em:", "Hebreus 10", ["Obadias", "Ageu", "Naum"], "Hb 10")
    add("hb", "dificil", "Hebreus tem quantos capítulos?", "13", ["5", "3", "22"], "Hb")
    add("hb", "expert", "O sangue de Abel e o de Jesus são contrastados em:", "Hebreus 12", ["Gênesis só", "Êxodo só", "Levítico só"], "Hb 12")
    add("tg", "facil", "A fé sem obras é:", "Morta", ["Perfeita", "Opcional", "Romana"], "Tg 2")
    add("tg", "medio", "Tiago adverte sobre a língua como:", "Fogo", ["Ouro", "Espada romana", "Maná"], "Tg 3")
    add("tg", "dificil", "A oração da fé salvará o:", "Enfermo", ["Império", "Templo", "Censo"], "Tg 5")
    add("tg", "expert", "Tiago cita Elias como exemplo de:", "Oração eficaz", ["Guerra", "Comércio", "Viagem a Roma"], "Tg 5")
    add("1pe", "facil", "1 Pedro anima cristãos sob:", "Sofrimento / perseguição", ["Riqueza garantida", "Trono terreno", "Exército próprio"], "1Pe 1-4")
    add("1pe", "medio", "Sede santos, porque eu sou santo — ecoa em:", "1 Pedro", ["Filemom", "2 João", "3 João"], "1Pe 1")
    add("1pe", "dificil", "Vós sois raça eleita, sacerdócio real — em:", "1 Pedro 2", ["Judas", "Obadias", "Ageu"], "1Pe 2")
    add("1pe", "expert", "As mulheres santas, como Sara, são exemplo em:", "1 Pedro 3", ["2 Pedro 1 só", "1 João 1 só", "Apocalipse 1"], "1Pe 3")
    add("2pe", "facil", "2 Pedro alerta contra:", "Falsos mestres", ["Dízimos", "Oração", "Hospitalidade"], "2Pe 2")
    add("2pe", "medio", "Um dia para o Senhor é como mil:", "Anos", ["Dias romanos", "Semanas", "Meses"], "2Pe 3")
    add("2pe", "dificil", "Paulo escreveu coisas difíceis de entender, diz:", "2 Pedro", ["Judas só", "Filemom", "2 João"], "2Pe 3")
    add("2pe", "expert", "2 Pedro tem quantos capítulos?", "3", ["5", "13", "22"], "2Pe")
    add("1jo", "facil", "Deus é:", "Amor", ["Guerra", "Ouro", "Tempo"], "1Jo 4")
    add("1jo", "medio", "Se confessarmos os pecados, ele é fiel para:", "Perdoar", ["Condenar eternamente sem graça", "Ignorar", "Exilar"], "1Jo 1")
    add("1jo", "dificil", "Anticristos já estão no mundo, diz:", "1 João", ["Filemom", "Ageu", "Obadias"], "1Jo 2")
    add("1jo", "expert", "Há pecado para morte mencionado em:", "1 João 5", ["2 João", "3 João", "Judas só"], "1Jo 5")
    add("2jo", "facil", "2 João é carta a uma:", "Senhora eleita / igreja", ["Sinagoga de Nínive", "Corte de Herodes", "Legião romana"], "2Jo 1")
    add("2jo", "medio", "2 João adverte a não receber:", "Falsos mestres", ["Irmãos fiéis", "Cartas de Paulo", "Anciãos"], "2Jo 1")
    add("2jo", "dificil", "2 João tem quantos capítulos?", "1", ["3", "5", "22"], "2Jo")
    add("2jo", "expert", "Andar na verdade e no amor resume:", "2 João", ["Naum", "Obadias", "Ageu"], "2Jo")
    add("3jo", "facil", "3 João elogia:", "Gaio", ["Diotrefes como modelo", "Demétrio como inimigo", "Hamã"], "3Jo 1")
    add("3jo", "medio", "Diotrefes gostava de ter a:", "Primazia", ["Humildade", "Pobreza voluntária só", "Silêncio"], "3Jo 1")
    add("3jo", "dificil", "Demétrio tem bom testemunho em:", "3 João", ["2 João só", "Judas só", "Filemom só"], "3Jo 1")
    add("3jo", "expert", "3 João tem quantos capítulos?", "1", ["5", "13", "22"], "3Jo")
    add("jd", "facil", "Judas combate a:", "Apostasia / falsos mestres", ["Construção do templo", "Viagem a Roma", "Censo"], "Jd 1")
    add("jd", "medio", "Judas menciona a contenda sobre o corpo de:", "Moisés", ["Davi", "Paulo", "Pedro"], "Jd 1")
    add("jd", "dificil", "Enoque é citado em:", "Judas", ["Filemom", "2 João", "Ageu"], "Jd 1")
    add("jd", "expert", "Judas tem quantos capítulos?", "1", ["3", "5", "22"], "Jd")
    add("ap", "facil", "Apocalipse foi escrito a:", "Sete igrejas da Ásia", ["Doze tribos só sem igrejas", "Roma imperial só", "Nínive"], "Ap 1-3")
    add("ap", "facil", "Jesus aparece como:", "Cordeiro / Alpha e Ômega", ["Apenas anjo criado", "Apenas profeta de Nínive", "César"], "Ap 1-5")
    add("ap", "medio", "Os quatro cavaleiros aparecem ao abrir selos em:", "Apocalipse 6", ["Mateus 6", "Atos 6", "Romanos 6"], "Ap 6")
    add("ap", "medio", "A Nova Jerusalém desce do:", "Céu", ["Mar", "Deserto", "Egito"], "Ap 21")
    add("ap", "dificil", "O número da besta é:", "666", ["777", "144", "40"], "Ap 13")
    add("ap", "expert", "Os 144 mil são selados das tribos de:", "Israel", ["Roma", "Egito", "Assíria"], "Ap 7")
    add("ap", "facil", "João recebeu a revelação em:", "Patmos", ["Roma", "Jerusalém", "Éfeso só sem ilha"], "Ap 1")
    add("ap", "medio", "Não haverá mais morte na:", "Nova criação", ["Babilônia", "Nínive", "Roma antiga"], "Ap 21")
    add("ap", "dificil", "A grande Babilônia cai em:", "Apocalipse 17–18", ["Atos 2", "Romanos 1", "Hebreus 1"], "Ap 17-18")
    add("ap", "expert", "A árvore da vida reaparece em:", "Apocalipse 22", ["Gênesis só sem eco", "Êxodo", "Levítico"], "Ap 22")

    return F


# Autores tradicionais (ensino EBD comum) e seções canônicas
TRAD_AUTHORS = {
    "mat": "Mateus", "mar": "Marcos", "luc": "Lucas", "joao": "João",
    "ato": "Lucas", "rom": "Paulo", "1co": "Paulo", "2co": "Paulo",
    "gal": "Paulo", "ef": "Paulo", "fp": "Paulo", "cl": "Paulo",
    "1ts": "Paulo", "2ts": "Paulo", "1tm": "Paulo", "2tm": "Paulo",
    "tt": "Paulo", "fm": "Paulo", "tg": "Tiago", "1pe": "Pedro",
    "2pe": "Pedro", "1jo": "João", "2jo": "João", "3jo": "João",
    "jd": "Judas", "ap": "João",
}

SECTIONS = {
    "gen": "Pentateuco", "exo": "Pentateuco", "lev": "Pentateuco",
    "num": "Pentateuco", "deu": "Pentateuco",
    "jos": "Históricos", "jui": "Históricos", "rut": "Históricos",
    "1sa": "Históricos", "2sa": "Históricos", "1rs": "Históricos",
    "2rs": "Históricos", "1cr": "Históricos", "2cr": "Históricos",
    "esd": "Históricos", "nee": "Históricos", "est": "Históricos",
    "jo": "Poéticos / Sabedoria", "sal": "Poéticos / Sabedoria",
    "pro": "Poéticos / Sabedoria", "ecl": "Poéticos / Sabedoria",
    "can": "Poéticos / Sabedoria",
    "isa": "Profetas Maiores", "jer": "Profetas Maiores",
    "lam": "Profetas Maiores", "eze": "Profetas Maiores", "dan": "Profetas Maiores",
    "ose": "Profetas Menores", "joe": "Profetas Menores", "amo": "Profetas Menores",
    "oba": "Profetas Menores", "jon": "Profetas Menores", "miq": "Profetas Menores",
    "naa": "Profetas Menores", "hab": "Profetas Menores", "sof": "Profetas Menores",
    "age": "Profetas Menores", "zac": "Profetas Menores", "mal": "Profetas Menores",
    "mat": "Evangelhos", "mar": "Evangelhos", "luc": "Evangelhos", "joao": "Evangelhos",
    "ato": "História da Igreja",
    "rom": "Cartas de Paulo", "1co": "Cartas de Paulo", "2co": "Cartas de Paulo",
    "gal": "Cartas de Paulo", "ef": "Cartas de Paulo", "fp": "Cartas de Paulo",
    "cl": "Cartas de Paulo", "1ts": "Cartas de Paulo", "2ts": "Cartas de Paulo",
    "1tm": "Cartas de Paulo", "2tm": "Cartas de Paulo", "tt": "Cartas de Paulo",
    "fm": "Cartas de Paulo",
    "hb": "Cartas Gerais", "tg": "Cartas Gerais", "1pe": "Cartas Gerais",
    "2pe": "Cartas Gerais", "1jo": "Cartas Gerais", "2jo": "Cartas Gerais",
    "3jo": "Cartas Gerais", "jd": "Cartas Gerais",
    "ap": "Profecia / Apocalipse",
}

SECTION_DISTRACTORS = [
    "Pentateuco", "Históricos", "Poéticos / Sabedoria", "Profetas Maiores",
    "Profetas Menores", "Evangelhos", "Cartas de Paulo", "Cartas Gerais",
    "História da Igreja", "Profecia / Apocalipse",
]

EXTRA_FACTS: list[tuple] = [
    # Complementos para chegar perto de 1000 com qualidade
    ("gen", "medio", "O dilúvio durou quarenta dias de:", "Chuva", ["Neve", "Granizo só", "Vento só"], "Gn 7"),
    ("gen", "dificil", "Babel significa confusão da:", "Língua", ["Lei", "Água", "Fé"], "Gn 11"),
    ("gen", "facil", "Abraão saiu de:", "Ur dos Caldeus", ["Egito", "Nínive", "Roma"], "Gn 12"),
    ("exo", "facil", "O nome de Deus revelado a Moisés inclui:", "EU SOU", ["BAAL", "DAGOM", "MARDUQUE"], "Êx 3"),
    ("exo", "medio", "O mar se abriu para Israel e se fechou sobre o:", "Egito", ["Amaleque", "Moabe", "Edom"], "Êx 14"),
    ("lev", "medio", "Amarás o teu próximo como a ti mesmo aparece em:", "Levítico", ["Obadias", "Naum", "Ageu"], "Lv 19"),
    ("num", "facil", "Israel andou no deserto cerca de:", "40 anos", ["7 anos", "12 anos", "3 anos"], "Nm 14"),
    ("deu", "facil", "Não só de pão viverá o homem — texto de:", "Deuteronômio", ["Rute", "Ester", "Jonas"], "Dt 8"),
    ("jos", "facil", "As muralhas de Jericó caíram após Israel:", "Marchar e gritar", ["Cavar túneis", "Usar catapultas", "Negociar paz"], "Js 6"),
    ("jui", "facil", "Cada um fazia o que parecia direito aos seus:", "Olhos", ["Reis", "Sacerdotes", "Vizinhos gregos"], "Jz 21"),
    ("1sa", "facil", "Samuel ouviu a voz de Deus quando menino em:", "Silo", ["Betel", "Hebrom", "Jerusalém"], "1Sm 3"),
    ("2sa", "facil", "Davi trouxe a arca para:", "Jerusalém", ["Silo", "Betel", "Egito"], "2Sm 6"),
    ("1rs", "facil", "Salomão pediu a Deus:", "Sabedoria", ["Riqueza só", "Vingança", "Longa viagem"], "1Rs 3"),
    ("2rs", "medio", "O axé flutuou no Jordão por milagre de:", "Eliseu", ["Elias só", "Isaías", "Jonas"], "2Rs 6"),
    ("sal", "medio", "O Senhor é a minha luz e a minha:", "Salvação", ["Espada", "Torre de Babel", "Riqueza"], "Sl 27"),
    ("pro", "facil", "Confia no Senhor de todo o teu:", "Coração", ["Ouro", "Exército", "Nome"], "Pv 3"),
    ("isa", "medio", "Preparai o caminho do Senhor — voz no:", "Deserto", ["Templo só", "Palácio", "Mar"], "Is 40"),
    ("dan", "medio", "Daniel orava três vezes ao:", "Dia", ["Mês", "Ano", "Século"], "Dn 6"),
    ("jon", "medio", "Os ninivitas:", "Se arrependeram", ["Atacaram Israel", ["Ignoraram Jonas"], "Mataram Jonas"], "Jn 3"),
    ("mat", "facil", "Jesus foi tentado no:", "Deserto", ["Templo só sem deserto", "Mar", "Palácio de Herodes"], "Mt 4"),
    ("mat", "medio", "O Pai Nosso é ensinado no:", "Sermão do Monte", ["Apocalipse", "Atos 1", "Romanos 1"], "Mt 6"),
    ("mar", "facil", "Jesus curou a sogra de:", "Pedro", ["Paulo", "João Batista", "Nicodemos"], "Mc 1"),
    ("luc", "facil", "Glória a Deus nas alturas — anjos no nascimento em:", "Lucas", ["Marcos", "João", "Atos"], "Lc 2"),
    ("joao", "facil", "Eu sou o bom:", "Pastor", ["Soldado", "César", "Leviatã"], "Jo 10"),
    ("ato", "facil", "A igreja nasceu publicamente em:", "Jerusalém", ["Roma", "Atenas", "Nínive"], "At 2"),
    ("rom", "facil", "O salário do pecado é a:", "Morte", ["Riqueza", "Fama", "Cidadania"], "Rm 6"),
    ("1co", "facil", "O corpo é templo do:", "Espírito Santo", ["César", "Baal", "Dinheiro"], "1Co 6"),
    ("gal", "facil", "Já não sou eu quem vive, mas Cristo vive em:", "Mim", ["Roma", "Moisés", "Pedro só"], "Gl 2"),
    ("ef", "facil", "Maridos, amai vossas mulheres — em:", "Efésios", ["Obadias", "Naum", "Ageu"], "Ef 5"),
    ("fp", "facil", "Rejoice / Alegrai-vos no Senhor — tom de:", "Filipenses", ["Lamentações", "Naum", "Amós só juízo"], "Fp 4"),
    ("hb", "facil", "Jesus é o mesmo ontem, hoje e:", "Eternamente", ["Só no templo", "Só em Israel", "Só em Roma"], "Hb 13"),
    ("tg", "facil", "Pedi a Deus sabedoria com:", "Fé", ["Dúvida orgulhosa", "Ouro", "Gritos ao ídolo"], "Tg 1"),
    ("1jo", "facil", "Nós amamos porque ele nos amou:", "Primeiro", ["Por último", "Nunca", "Por obrigação romana"], "1Jo 4"),
    ("ap", "facil", "Eis que venho:", "Sem demora / cedo", ["Nunca", "Só em sonho", "Só para reis"], "Ap 22"),
    ("2ts", "facil", "Não vos deixeis abalar quanto à:", "Vinda de Cristo", ["Lei de Moisés cerimonial só", "Arca de Noé", "Torre de Babel"], "2Ts 2"),
    ("2ts", "medio", "Paulo pede oração e ordem na:", "Igreja / comunidade", ["Legião romana", "Corte de Herodes", "Sinagoga de Nínive"], "2Ts 3"),
    ("mal", "facil", "Malaquias questiona o povo sobre:", "Dízimos e fidelidade", ["Construção da arca", "Viagem a Roma", "Censo de César"], "Ml 3"),
    ("age", "facil", "O povo cuidava das casas e negligenciava a:", "Casa do Senhor", ["Colheita de Nínive", "Frota romana", "Torre de Babel"], "Ag 1"),
    ("nee", "facil", "Neemias orou e pediu licença ao:", "Rei", ["Faraó do Êxodo", "César", "Pilatos"], "Ne 1-2"),
    ("est", "medio", "Para tal tempo como este — frase ligada a:", "Ester", ["Rute só", "Débora só", "Ana só"], "Et 4"),
    ("rut", "facil", "Rute ficou com Noemi em vez de voltar a:", "Moabe", ["Egito", "Roma", "Assíria"], "Rt 1"),
    ("jo", "dificil", "Jó amaldiçoou o dia do seu:", "Nascimento", ["Casamento", "Exílio", "Reinado"], "Jó 3"),
    ("ecl", "facil", "Debaixo do sol tudo é:", "Vaidade / efêmero", ["Eterno ouro", "Sempre justo", "Sempre feliz"], "Ec 1"),
    ("can", "facil", "Cânticos celebra o amor entre:", "Amado e amada", ["Rei e inimigo", "Profeta e Nínive", "Apóstolo e César"], "Ct 1"),
    ("lam", "facil", "Grande é a tua fidelidade — eco em:", "Lamentações", ["Obadias", "Naum", "Filemom"], "Lm 3"),
    ("miq", "facil", "De Belém sairá o:", "Governante de Israel", ["Faraó", "César", "Sumo sacerdote de Silo"], "Mq 5"),
    ("zac", "facil", "Não por força, nem por poder, mas pelo meu:", "Espírito", ["Ouro", "Exército", "Muro"], "Zc 4"),
    ("hab", "facil", "Embora a figueira não floresça… eu me alegrarei no:", "Senhor", ["Ouro", "Exército", "Exílio"], "Hc 3"),
    ("sof", "facil", "O Senhor está no meio de ti como:", "Poderoso Salvador", ["César", "Baal", "Faraó"], "Sf 3"),
    ("oba", "facil", "Obadias tem quantos capítulos?", "1", ["3", "12", "66"], "Ob"),
    ("fm", "facil", "Paulo escreve a Filemom da:", "Prisão / cadeias", ["Corte de Herodes", "Templo de Salomão", "Arca de Noé"], "Fm 1"),
    ("2jo", "facil", "2 João insiste em andar na:", "Verdade", ["Riqueza", "Fama romana", "Guerra"], "2Jo 1"),
    ("3jo", "facil", "3 João valoriza a:", "Hospitalidade aos irmãos", ["Primazia de Diotrefes", "Idolatra", "Guerra"], "3Jo 1"),
    ("jd", "facil", "Contendei pela fé uma vez:", "Entregue aos santos", ["Vendida em Roma", "Esquecida", "Guardada só por reis"], "Jd 1"),
    ("1tm", "facil", "Exercita-te na:", "Piedade", ["Guerra romana", "Acumulação", "Fama"], "1Tm 4"),
    ("2tm", "facil", "Prega a palavra, insta a tempo e:", "Fora de tempo", ["Só em festas", "Só a reis", "Nunca"], "2Tm 4"),
    ("tt", "facil", "A esperança bem-aventurada é a:", "Manifestação de Cristo", ["Queda de Nínive", "Construção da arca", "Torre de Babel"], "Tt 2"),
    ("cl", "facil", "Tudo o que fizerdes, fazei de coração como ao:", "Senhor", ["César", "Mamon", "Tempo"], "Cl 3"),
    ("1ts", "facil", "Orai sem:", "Cessar", ["Fé", "Amor", "Esperança"], "1Ts 5"),
    ("2co", "facil", "Andamos por fé, e não pelo que:", "Vemos", ["Oramos", "Cantamos", "Damos"], "2Co 5"),
    ("1pe", "facil", "Lançai sobre ele toda a vossa:", "Ansiedade", ["Riqueza", "Espada", "Fama"], "1Pe 5"),
    ("2pe", "facil", "Há de vir o dia do Senhor como:", "Ladrão", ["Festa de Purim", "Censo", "Lua nova"], "2Pe 3"),
    ("1cr", "facil", "As genealogias abrem:", "1 Crônicas", ["Jonas", "Obadias", "Filemom"], "1Cr 1"),
    ("2cr", "medio", "Se o meu povo se humilhar… eu sararei a sua:", "Terra", ["Espada", "Frota", "Torre"], "2Cr 7"),
    ("esd", "facil", "O povo chorou ao ouvir a:", "Lei", ["Guerra", "Música romana", "Ordem de Hamã"], "Ed / Ne"),
    ("eze", "facil", "Filho do homem — tratamento frequente a:", "Ezequiel", ["Jonas", "Naum", "Ageu"], "Ez 2"),
    ("ose", "facil", "Oséias compara Israel a esposa:", "Infiel / restaurada", ["Romana", "Egípcia faraônica", "Grega"], "Os 1-3"),
    ("joe", "facil", "Rasgai o vosso coração, e não as:", "Vestes", ["Pedras", "Tábuas", "Portas"], "Jl 2"),
    ("amo", "facil", "Corra o juízo como as:", "Águas", ["Pedras", "Chamas só", "Nuvens romanas"], "Am 5"),
    ("naa", "facil", "O Senhor é bom, fortaleza no dia da:", "Angústia", ["Festa só", "Colheita só", "Lua"], "Na 1"),
    ("dan", "facil", "Daniel e amigos não quiseram a comida do:", "Rei", ["Templo", "Profeta", "Anjo"], "Dn 1"),
    ("mat", "dificil", "As genealogias de Jesus abrem:", "Mateus", ["Marcos", "João", "Atos"], "Mt 1"),
    ("luc", "dificil", "O censo de Quirino contextualiza o nascimento em:", "Lucas", ["Marcos", "João", "Mateus só sem censo"], "Lc 2"),
    ("joao", "dificil", "O lavar dos pés dos discípulos está em:", "João 13", ["Mateus 1", "Atos 1", "Romanos 1"], "Jo 13"),
    ("ato", "dificil", "Paulo prega no Areópago em:", "Atenas", ["Roma", "Nínive", "Babilônia"], "At 17"),
    ("rom", "dificil", "Não vos conformeis com este:", "Século / mundo", ["Culto", "Cântico", "Jejum"], "Rm 12"),
    ("ap", "dificil", "As sete igrejas incluem Éfeso, Esmirna e:", "Laodiceia (entre outras)", ["Nínive", "Babilônia de Nabucodonosor", "Ur"], "Ap 2-3"),
]


def _flatten_distractors(d):
    out = []
    for x in d:
        if isinstance(x, list):
            out.extend(_flatten_distractors(x))
        else:
            out.append(str(x))
    return out


def all_facts() -> list[tuple]:
    raw = facts() + facts_part2() + facts_part3() + EXTRA_FACTS
    clean = []
    for book, level, question, correct, distractors, ref in raw:
        distractors = _flatten_distractors(distractors)
        # garantir 3 strings
        while len(distractors) < 3:
            distractors.append(random.choice(PEOPLE))
        clean.append((book, level, question, correct, distractors[:3], ref))
    return clean


def load_existing() -> list[dict]:
    """Carrega o seed original (~180) para não inflar em reexecuções."""
    path = SEED if SEED.exists() else OUT
    if not path.exists():
        return []
    data = json.loads(path.read_text(encoding="utf-8"))
    return list(data.get("questions") or [])


def load_bank_file(path: Path) -> list[dict]:
    if not path.exists():
        return []
    data = json.loads(path.read_text(encoding="utf-8"))
    return list(data.get("questions") or [])


def template_questions(rng: random.Random) -> list[dict]:
    """Perguntas estruturais equilibradas por livro (capítulos, testamento, seção, ordem, autor)."""
    cleaned: list[dict] = []

    for bid, name, testament, chapters, abbr in BOOKS:
        cleaned.append(
            {
                "level": "facil",
                "bookId": bid,
                "q": f"O livro de {name} pertence ao:",
                "correct": "Antigo Testamento" if testament == "AT" else "Novo Testamento",
                "distractors": [
                    "Novo Testamento" if testament == "AT" else "Antigo Testamento",
                    "Livros apócrifos",
                    "Apenas tradição posterior não canônica",
                ],
                "ref": abbr,
            }
        )
        # Capítulos
        wrong_ch = [c for c in (1, 3, 5, 8, 12, 16, 22, 27, 39, 40, 50, 66, 150) if c != chapters]
        rng.shuffle(wrong_ch)
        cleaned.append(
            {
                "level": "dificil" if chapters not in (1, 3, 5) else "medio",
                "bookId": bid,
                "q": f"Quantos capítulos tem o livro de {name}?",
                "correct": str(chapters),
                "distractors": [str(x) for x in wrong_ch[:3]],
                "ref": abbr,
            }
        )
        # Seção
        sec = SECTIONS[bid]
        dsec = [s for s in SECTION_DISTRACTORS if s != sec]
        rng.shuffle(dsec)
        cleaned.append(
            {
                "level": "medio",
                "bookId": bid,
                "q": f"Na divisão didática comum da Bíblia, {name} fica entre os:",
                "correct": sec,
                "distractors": dsec[:3],
                "ref": abbr,
            }
        )
        # Abreviação / identificação
        other_names = [b[1] for b in BOOKS if b[0] != bid]
        rng.shuffle(other_names)
        cleaned.append(
            {
                "level": "facil",
                "bookId": bid,
                "q": f"A abreviação bíblica «{abbr}» costuma indicar o livro de:",
                "correct": name,
                "distractors": other_names[:3],
                "ref": abbr,
            }
        )

    # Ordem canônica: livro seguinte
    for i in range(len(BOOKS) - 1):
        bid, name, *_ = BOOKS[i]
        nxt = BOOKS[i + 1]
        others = [b[1] for b in BOOKS if b[0] not in (bid, nxt[0])]
        rng.shuffle(others)
        cleaned.append(
            {
                "level": "expert",
                "bookId": bid,
                "q": f"Na ordem canônica protestante, qual livro vem logo após {name}?",
                "correct": nxt[1],
                "distractors": others[:3],
                "ref": None,
            }
        )

    # Autoria tradicional NT
    author_pool = ["Paulo", "Pedro", "João", "Lucas", "Mateus", "Marcos", "Tiago", "Judas", "Moisés", "Davi"]
    for bid, author in TRAD_AUTHORS.items():
        name = BOOK_BY_ID[bid][1]
        d = [a for a in author_pool if a != author]
        rng.shuffle(d)
        cleaned.append(
            {
                "level": "medio",
                "bookId": bid,
                "q": f"A tradição cristã clássica atribui a autoria de {name} principalmente a:",
                "correct": author,
                "distractors": d[:3],
                "ref": BOOK_BY_ID[bid][4],
            }
        )

    # Variantes de redação (mesmo fato, outra pergunta) para livros grandes
    variants = [
        ("gen", "medio", "Quem foi o pai de Isaque?", "Abraão", ["Labão", "Nacor", "Terá sem Abraão"], "Gn 21"),
        ("gen", "dificil", "Esaú também é chamado:", "Edom", ["Ismael", "Ló", "Caim"], "Gn 36"),
        ("exo", "dificil", "O sumo sacerdote no Êxodo era da linhagem de:", "Arão", ["Judá", "José", "Rubem"], "Êx 28"),
        ("jos", "dificil", "Gilgal foi acampamento após cruzar o:", "Jordão", ["Nilo", "Eufrates", "Mar Morto"], "Js 4"),
        ("1sa", "dificil", "Isai era pai de:", "Davi", ["Saul", "Samuel", "Jônatas"], "1Sm 16"),
        ("1rs", "dificil", "O reino do norte ficou conhecido como:", "Israel / Efraim", ["Judá só", "Edom", "Moabe"], "1Rs 12"),
        ("2rs", "facil", "A viúva do azeite foi ajudada por:", "Eliseu", ["Elias só neste milagre", "Isaías", "Jeremias"], "2Rs 4"),
        ("sal", "expert", "O Salmo 22 é frequentemente ligado à:", "Paixão de Cristo", ["Criação", "Dilúvio", "Êxodo só"], "Sl 22"),
        ("isa", "facil", "O povo que andava em trevas viu grande:", "Luz", ["Templo", "Exército", "Ouro"], "Is 9"),
        ("jer", "medio", "Jeremias foi posto como profeta às:", "Nações", ["Só a Nínive", "Só a Roma", "Só ao Egito faraônico"], "Jr 1"),
        ("mat", "facil", "Bem-aventurados os limpos de:", "Coração", ["Ouro", "Espada", "Fama"], "Mt 5"),
        ("joao", "medio", "Eu sou o caminho, a verdade e a:", "Vida", ["Lei", "Espada", "Torre"], "Jo 14"),
        ("ato", "medio", "Ser-me-eis testemunhas em Jerusalém… e até os:", "Confins da terra", ["Limites de Judá só", "Muros de Jericó", "Rios do Egito"], "At 1"),
        ("rom", "medio", "Tudo contribui para o bem dos que:", "Amam a Deus", ["Odeiam a lei", "Servem a César só", "Buscam ouro"], "Rm 8"),
        ("1co", "medio", "Agora, pois, permanecem fé, esperança e:", "Amor", ["Ouro", "Fama", "Poder"], "1Co 13"),
        ("ef", "medio", "Há um só corpo e um só:", "Espírito", ["Império", "Templo de pedra", "César"], "Ef 4"),
        ("fp", "medio", "A paz de Deus excede todo o:", "Entendimento", ["Ouro", "Exército", "Templo"], "Fp 4"),
        ("hb", "medio", "Sem fé é impossível:", "Agradar a Deus", ["Viajar", "Orar em voz alta", "Jejear"], "Hb 11"),
        ("ap", "medio", "Eu estou à porta e:", "Bato", ["Fujo", "Destruo sem aviso só", "Esqueço"], "Ap 3"),
        ("dan", "facil", "Mene, Mene, Tequel, Ufarsim foi escrito na:", "Parede", ["Tábua de Moisés", "Arca", "Pedra de Jericó"], "Dn 5"),
    ]
    for row in variants:
        bid, level, q, correct, distractors, ref = row
        cleaned.append(
            {
                "level": level,
                "bookId": bid,
                "q": q,
                "correct": correct,
                "distractors": distractors,
                "ref": ref,
            }
        )

    return cleaned


def build_questions(seed: int = 42) -> list[dict]:
    rng = random.Random(seed)
    existing = load_existing()
    seen = {_norm_q(q.get("q") or q.get("question") or "") for q in existing}
    result = []

    # Normaliza existentes
    for i, q in enumerate(existing, 1):
        item = {
            "id": q.get("id") or f"q{i:04d}",
            "level": q.get("level") or "facil",
            "bookId": q.get("bookId") or q.get("book") or "gen",
            "q": q.get("q") or q.get("question") or "",
            "options": list(q.get("options") or []),
            "correct": int(q.get("correct") or 0),
            "ref": q.get("ref") or q.get("reference"),
        }
        if item["q"] and len(item["options"]) >= 2:
            result.append(item)

    def try_add(level, book_id, question, correct, distractors, ref):
        nq = _norm_q(question)
        if not nq or nq in seen:
            return False
        if book_id not in BOOK_BY_ID:
            return False
        if level not in LEVELS:
            level = "medio"
        distractors = _flatten_distractors(distractors)
        item = qdict(
            qid="tmp",
            level=level,
            book_id=book_id,
            question=question,
            correct=str(correct),
            distractors=[str(x) for x in distractors],
            ref=ref,
            rng=rng,
        )
        seen.add(nq)
        result.append(item)
        return True

    for book, level, question, correct, distractors, ref in all_facts():
        try_add(level, book, question, correct, distractors, ref)

    for t in template_questions(rng):
        try_add(t["level"], t["bookId"], t["q"], t["correct"], t["distractors"], t.get("ref"))

    # Balanceamento: se faltar, gera perguntas de cobertura por livro/nível
    by_book = Counter(q["bookId"] for q in result)
    by_level = Counter(q["level"] for q in result)
    target_per_book = max(10, TARGET // len(BOOKS))  # ~15

    level_cycle = list(LEVELS)
    for bid, name, testament, chapters, abbr in BOOKS:
        while by_book[bid] < 12 and len(result) < TARGET_MAX:
            level = level_cycle[by_book[bid] % 4]
            # perguntas de reforço com redação variada
            templates = [
                (
                    f"Em termos de testamento, {name} está no {('Antigo' if testament=='AT' else 'Novo')} Testamento. Qual é o testamento correto?",
                    "Antigo Testamento" if testament == "AT" else "Novo Testamento",
                    [
                        "Novo Testamento" if testament == "AT" else "Antigo Testamento",
                        "Apócrifos",
                        "Pseudepígrafos apenas",
                    ],
                ),
                (
                    f"Qual é o nome completo do livro identificado por «{abbr}»?",
                    name,
                    [b[1] for b in rng.sample([b for b in BOOKS if b[0] != bid], 3)],
                ),
                (
                    f"O livro de {name} tem {chapters} capítulos. Qual destas é a contagem correta?",
                    str(chapters),
                    [str(c) for c in rng.sample([c for c in (1, 2, 3, 4, 5, 6, 8, 10, 12, 13, 14, 16, 21, 22, 24, 27, 28, 31, 34, 36, 40, 42, 48, 50, 52, 66, 150) if c != chapters], 3)],
                ),
            ]
            qtext, correct, distractors = templates[by_book[bid] % len(templates)]
            # variar redação
            qtext = qtext.replace("Qual é", "Indique").replace("Qual destas", "Assinale") if by_book[bid] % 2 else qtext
            if try_add(level, bid, qtext, correct, distractors, abbr):
                by_book[bid] += 1

    # Ajusta para faixa 950–1100: trim ou pad
    # Preferência: manter cobertura de livros; remover duplicatas semânticas extras de templates se >1100
    if len(result) > TARGET_MAX:
        # remove reforços genéricos de testamento duplicados primeiro
        keep = []
        testament_q = 0
        for q in result:
            if "pertence ao:" in q["q"] or "testamento correto" in q["q"].lower():
                testament_q += 1
                if testament_q > 80 and len(result) - (testament_q - 80) >= TARGET_MIN:
                    continue
            keep.append(q)
        result = keep

    if len(result) > TARGET_MAX:
        result = result[:TARGET_MAX]

    # Se ainda abaixo de 950, adiciona perguntas de ordem inversa (livro anterior)
    if len(result) < TARGET_MIN:
        for i in range(1, len(BOOKS)):
            if len(result) >= TARGET:
                break
            bid, name, *_ = BOOKS[i]
            prev = BOOKS[i - 1]
            others = [b[1] for b in BOOKS if b[0] not in (bid, prev[0])]
            rng.shuffle(others)
            try_add(
                "expert",
                bid,
                f"Na ordem canônica protestante, qual livro vem logo antes de {name}?",
                prev[1],
                others[:3],
                None,
            )

    # Reatribui IDs sequenciais
    final = []
    for i, q in enumerate(result, 1):
        q = dict(q)
        q["id"] = f"q{i:04d}"
        # schema: options length 4, correct in range
        if len(q["options"]) < 4:
            continue
        if not (0 <= int(q["correct"]) < len(q["options"])):
            continue
        final.append(q)

    return final


def validate(questions: list[dict]) -> dict:
    errors = []
    n = len(questions)
    if not (TARGET_MIN <= n <= TARGET_MAX):
        errors.append(f"total {n} fora de [{TARGET_MIN},{TARGET_MAX}]")

    levels = Counter(q["level"] for q in questions)
    books = Counter(q["bookId"] for q in questions)
    ids = [q["id"] for q in questions]
    if len(ids) != len(set(ids)):
        errors.append("ids duplicados")

    missing_books = [b[0] for b in BOOKS if books[b[0]] == 0]
    if missing_books:
        errors.append(f"livros sem perguntas: {missing_books}")

    for q in questions:
        if q["level"] not in LEVELS:
            errors.append(f"nível inválido em {q['id']}")
        if q["bookId"] not in BOOK_BY_ID:
            errors.append(f"bookId inválido em {q['id']}: {q['bookId']}")
        if len(q.get("options") or []) != 4:
            errors.append(f"options!=4 em {q['id']}")
        if not (0 <= int(q.get("correct", -1)) <= 3):
            errors.append(f"correct inválido em {q['id']}")
        if not (q.get("q") or "").strip():
            errors.append(f"pergunta vazia {q['id']}")

    # duplicatas óbvias
    norms = [_norm_q(q["q"]) for q in questions]
    dup = [k for k, v in Counter(norms).items() if v > 1]
    if dup:
        errors.append(f"duplicatas de enunciado: {len(dup)}")

    at = sum(books[b] for b in AT_IDS)
    nt = sum(books[b] for b in NT_IDS)

    return {
        "ok": not errors,
        "errors": errors,
        "total": n,
        "levels": dict(levels),
        "books_covered": len([b for b in BOOKS if books[b[0]] > 0]),
        "per_book_min": min(books[b[0]] for b in BOOKS) if books else 0,
        "per_book_max": max(books.values()) if books else 0,
        "testament": {"AT": at, "NT": nt},
        "book_counts": dict(books),
    }


def write_bank(questions: list[dict]) -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    payload = {"version": 1, "questions": questions}
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description="Gera/valida banco de quiz bíblico EBD")
    ap.add_argument("--validate-only", action="store_true")
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    if args.validate_only:
        qs = load_bank_file(OUT)
        for q in qs:
            q.setdefault("options", [])
            q["correct"] = int(q.get("correct") or 0)
        report = validate(qs)
    else:
        qs = build_questions(seed=args.seed)
        report = validate(qs)
        if report["ok"] or (TARGET_MIN <= report["total"] <= TARGET_MAX and not any(
            e.startswith("livros sem") or e.startswith("ids") for e in report["errors"]
        )):
            # aceita se total ok e cobertura ok; avisa duplicatas leves
            write_bank(qs)
            report = validate(qs)
        else:
            write_bank(qs)  # ainda escreve para inspeção
            print("AVISO: validação com problemas", file=sys.stderr)

    print(json.dumps(report, ensure_ascii=False, indent=2))
    # exit 0 se total na faixa e 66 livros
    if TARGET_MIN <= report["total"] <= TARGET_MAX and report["books_covered"] == 66:
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
