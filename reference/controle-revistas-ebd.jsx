import { useState, useEffect, useMemo, useRef } from "react";

// "CIBE" e "Varões" são as duas turmas dentro do departamento de Adultos.
const GROUPS = [
  "Maternal (2-3 anos)",
  "Pré-escolar (4-5 anos)",
  "Primários (6-8 anos)",
  "Juniores (9-11 anos)",
  "Adolescentes 12-14",
  "Adolescentes 15-17",
  "Jovens",
  "CIBE",
  "Varões",
];
const REC_KEY = "ebd-registros-v4";
const ED_KEY = "ebd-edicoes-v4";
const FIN_KEY = "ebd-financas-v1";

// Catálogo oficial da Editora Betel (editorabetel.com.br), capturado no 2º Trimestre 2026.
// Como o navegador não pode buscar o site automaticamente, esta lista precisa ser
// atualizada manualmente a cada novo trimestre — é só pedir para o Claude atualizar.
// CIBE e Varões usam a mesma revista de Adultos da Betel.
const BETEL_CATALOG = {
  "Maternal (2-3 anos)": {
    trimestre: "2º Trimestre 2026",
    revista: "CRESCER+ Maternal",
    capa: "https://www.editorabetel.com.br/uploads/imagens/6a15b51ae13da_m.jpg",
  },
  "Pré-escolar (4-5 anos)": {
    trimestre: "2º Trimestre 2026",
    revista: "CONHECER+ Pré-escolar",
    capa: "https://www.editorabetel.com.br/uploads/imagens/6a15b6b6a8ee1_m.jpg",
  },
  "Primários (6-8 anos)": {
    trimestre: "2º Trimestre 2026",
    revista: "APRENDER+ Primários",
    capa: "https://www.editorabetel.com.br/uploads/imagens/6a15b85602e7b_m.jpg",
  },
  "Juniores (9-11 anos)": {
    trimestre: "2º Trimestre 2026",
    revista: "SABER+ Juniores",
    capa: "https://www.editorabetel.com.br/uploads/imagens/6a15baaab01bb_m.jpg",
  },
  "Adolescentes 12-14": {
    trimestre: "2º Trimestre 2026",
    revista: "ADOLESCER+",
    capa: "https://www.editorabetel.com.br/uploads/imagens/6a15bbfd69d8a_m.jpg",
  },
  "Adolescentes 15-17": {
    trimestre: "2º Trimestre 2026",
    revista: "VIVER+",
    capa: "https://www.editorabetel.com.br/uploads/imagens/6a15bd2e62a26_m.jpg",
  },
  "CIBE": {
    trimestre: "2º Trimestre 2026",
    revista: "Betel Dominical Adulto",
    capa: "https://www.editorabetel.com.br/uploads/imagens/6a15bf18ddb52_m.jpg",
  },
  "Varões": {
    trimestre: "2º Trimestre 2026",
    revista: "Betel Dominical Adulto",
    capa: "https://www.editorabetel.com.br/uploads/imagens/6a15bf18ddb52_m.jpg",
  },
};

function currency(n) {
  return (Number(n) || 0).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
}

function formatDate(iso) {
  return new Date(iso).toLocaleDateString("pt-BR", { day: "2-digit", month: "long", year: "numeric" });
}

function formatDayDate(dateStr) {
  // dateStr is "yyyy-mm-dd"
  const d = new Date(dateStr + "T12:00:00");
  return d.toLocaleDateString("pt-BR", { weekday: "long", day: "2-digit", month: "long", year: "numeric" });
}

function lastOrThisSunday() {
  const d = new Date();
  d.setDate(d.getDate() - d.getDay());
  return d.toISOString().slice(0, 10);
}

function resizeImage(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const img = new Image();
      img.onload = () => {
        const maxW = 480;
        const scale = Math.min(1, maxW / img.width);
        const canvas = document.createElement("canvas");
        canvas.width = img.width * scale;
        canvas.height = img.height * scale;
        const ctx = canvas.getContext("2d");
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        resolve(canvas.toDataURL("image/jpeg", 0.72));
      };
      img.onerror = reject;
      img.src = reader.result;
    };
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

function Stamp({ status, onClick }) {
  const paid = status === "pago";
  return (
    <button
      onClick={onClick}
      style={{
        fontFamily: "'IBM Plex Mono', monospace",
        fontSize: "11px",
        fontWeight: 700,
        letterSpacing: "0.12em",
        textTransform: "uppercase",
        padding: "5px 10px",
        border: `2px solid ${paid ? "#2F5D50" : "#9B2C2C"}`,
        color: paid ? "#2F5D50" : "#9B2C2C",
        background: paid ? "rgba(47,93,80,0.06)" : "rgba(155,44,44,0.06)",
        borderRadius: "3px",
        transform: "rotate(-3deg)",
        cursor: "pointer",
        whiteSpace: "nowrap",
      }}
      title="Toque para alternar pago / pendente"
    >
      {paid ? "Pago" : "Pendente"}
    </button>
  );
}

function editionTotalsOf(records, edId) {
  const base = records.filter((r) => r.edicaoId === edId);
  const pago = base.filter((r) => r.status === "pago").reduce((s, r) => s + r.valor, 0);
  const pendente = base.filter((r) => r.status === "pendente").reduce((s, r) => s + r.valor, 0);
  return { pago, pendente, count: base.length, items: base };
}

function financeTotalsOf(finances, grupo) {
  const base = finances.filter((f) => f.grupo === grupo);
  const ofertas = base.filter((f) => f.tipo === "oferta").reduce((s, f) => s + f.valor, 0);
  const doacoes = base.filter((f) => f.tipo === "doacao").reduce((s, f) => s + f.valor, 0);
  return { ofertas, doacoes, total: ofertas + doacoes, items: base.sort((a, b) => b.data.localeCompare(a.data)) };
}

function ReportView({ mode, tab, editions, records, finances, onClose }) {
  const groupsForReport = mode === "geral" ? GROUPS : [tab];
  const blocks = groupsForReport
    .map((g) => {
      const eds = editions.filter((e) => e.grupo === g).sort((a, b) => b.criadoEm.localeCompare(a.criadoEm));
      const current = eds[0] || null;
      const fin = financeTotalsOf(finances, g);
      if (!current && fin.items.length === 0) return null;
      return {
        grupo: g,
        edicao: current,
        totals: current ? editionTotalsOf(records, current.id) : { pago: 0, pendente: 0, count: 0, items: [] },
        fin,
      };
    })
    .filter(Boolean);

  const grand = blocks.reduce(
    (acc, b) => ({
      pago: acc.pago + b.totals.pago,
      pendente: acc.pendente + b.totals.pendente,
      ofertas: acc.ofertas + b.fin.ofertas,
      doacoes: acc.doacoes + b.fin.doacoes,
    }),
    { pago: 0, pendente: 0, ofertas: 0, doacoes: 0 }
  );
  const grandConsolidado = grand.pago + grand.ofertas + grand.doacoes;

  return (
    <div style={{ position: "fixed", inset: 0, background: "#F7F2E7", zIndex: 50, overflowY: "auto" }}>
      <style>{`
        @media print {
          .no-print { display: none !important; }
          body { background: #fff !important; }
        }
      `}</style>
      <div className="no-print" style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "16px 20px", borderBottom: "1px solid rgba(43,35,24,0.15)", position: "sticky", top: 0, background: "#F7F2E7", zIndex: 1 }}>
        <button onClick={onClose} style={{ border: "none", background: "none", color: "#2B2318", fontSize: "14px", fontWeight: 600, cursor: "pointer" }}>← Voltar</button>
        <button
          onClick={() => window.print()}
          style={{ padding: "9px 16px", borderRadius: "6px", border: "none", background: "#2F5D50", color: "#F7F2E7", fontWeight: 700, fontSize: "13px", cursor: "pointer" }}
        >
          Baixar / Imprimir PDF
        </button>
      </div>

      <div style={{ maxWidth: "680px", margin: "0 auto", padding: "28px 20px 60px", fontFamily: "'Inter', sans-serif", color: "#2B2318" }}>
        <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: "11px", letterSpacing: "0.14em", textTransform: "uppercase", color: "#B8892B" }}>
          Escola Bíblica Dominical
        </div>
        <h1 style={{ fontFamily: "'Libre Caslon Text', serif", fontStyle: "italic", fontSize: "26px", margin: "4px 0 2px" }}>
          {mode === "geral" ? "Relatório geral" : `Relatório — ${tab}`}
        </h1>
        <div style={{ fontSize: "12px", color: "#8B8378" }}>Gerado em {formatDate(new Date().toISOString())}</div>

        {blocks.length === 0 && (
          <div style={{ marginTop: "30px", color: "#8B8378", fontSize: "14px" }}>Nada cadastrado ainda para gerar relatório.</div>
        )}

        {blocks.map((b) => (
          <div key={b.grupo} style={{ marginTop: "28px", pageBreakInside: "avoid" }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", borderBottom: "2px solid #2B2318", paddingBottom: "6px" }}>
              <div style={{ fontSize: "16px", fontWeight: 700 }}>{b.grupo}{b.edicao ? ` — ${b.edicao.trimestre}` : ""}</div>
              {b.edicao && <div style={{ fontSize: "11px", color: "#8B8378" }}>{b.totals.count} entrega(s)</div>}
            </div>

            {b.edicao ? (
              b.totals.items.length === 0 ? (
                <div style={{ padding: "10px 0", fontSize: "13px", color: "#8B8378" }}>Sem entregas de revista registradas.</div>
              ) : (
                <table style={{ width: "100%", borderCollapse: "collapse", marginTop: "8px", fontSize: "13px" }}>
                  <thead>
                    <tr style={{ textAlign: "left", color: "#8B8378", fontSize: "11px", textTransform: "uppercase", letterSpacing: "0.04em" }}>
                      <th style={{ padding: "4px 0" }}>Nome</th>
                      <th style={{ padding: "4px 0", textAlign: "right" }}>Valor</th>
                      <th style={{ padding: "4px 0", textAlign: "right" }}>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {b.totals.items.map((r) => (
                      <tr key={r.id} style={{ borderTop: "1px dashed rgba(43,35,24,0.2)" }}>
                        <td style={{ padding: "6px 0" }}>{r.nome}</td>
                        <td style={{ padding: "6px 0", textAlign: "right", fontFamily: "'IBM Plex Mono', monospace" }}>{currency(r.valor)}</td>
                        <td style={{ padding: "6px 0", textAlign: "right", fontWeight: 700, color: r.status === "pago" ? "#2F5D50" : "#9B2C2C" }}>
                          {r.status === "pago" ? "Pago" : "Pendente"}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )
            ) : (
              <div style={{ padding: "10px 0", fontSize: "13px", color: "#8B8378" }}>Sem revista cadastrada.</div>
            )}
            {b.edicao && (
              <div style={{ display: "flex", justifyContent: "flex-end", gap: "16px", marginTop: "8px", fontSize: "12px" }}>
                <span style={{ color: "#2F5D50", fontWeight: 700 }}>Recebido: {currency(b.totals.pago)}</span>
                <span style={{ color: "#9B2C2C", fontWeight: 700 }}>Pendente: {currency(b.totals.pendente)}</span>
              </div>
            )}

            {b.fin.items.length > 0 && (
              <div style={{ marginTop: "16px" }}>
                <div style={{ fontSize: "12px", fontWeight: 700, textTransform: "uppercase", letterSpacing: "0.04em", color: "#B8892B" }}>
                  Ofertas e doações
                </div>
                <table style={{ width: "100%", borderCollapse: "collapse", marginTop: "6px", fontSize: "13px" }}>
                  <thead>
                    <tr style={{ textAlign: "left", color: "#8B8378", fontSize: "11px", textTransform: "uppercase", letterSpacing: "0.04em" }}>
                      <th style={{ padding: "4px 0" }}>Data</th>
                      <th style={{ padding: "4px 0" }}>Tipo</th>
                      <th style={{ padding: "4px 0" }}>Descrição</th>
                      <th style={{ padding: "4px 0", textAlign: "right" }}>Valor</th>
                    </tr>
                  </thead>
                  <tbody>
                    {b.fin.items.map((f) => (
                      <tr key={f.id} style={{ borderTop: "1px dashed rgba(43,35,24,0.2)" }}>
                        <td style={{ padding: "6px 0" }}>{new Date(f.data + "T12:00:00").toLocaleDateString("pt-BR")}</td>
                        <td style={{ padding: "6px 0" }}>{f.tipo === "oferta" ? "Oferta" : "Doação"}</td>
                        <td style={{ padding: "6px 0", color: "#8B8378" }}>{f.descricao || "—"}</td>
                        <td style={{ padding: "6px 0", textAlign: "right", fontFamily: "'IBM Plex Mono', monospace" }}>{currency(f.valor)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                <div style={{ display: "flex", justifyContent: "flex-end", gap: "16px", marginTop: "8px", fontSize: "12px" }}>
                  <span style={{ fontWeight: 700 }}>Ofertas: {currency(b.fin.ofertas)}</span>
                  <span style={{ fontWeight: 700 }}>Doações: {currency(b.fin.doacoes)}</span>
                </div>
              </div>
            )}
          </div>
        ))}

        {blocks.length > 0 && (
          <div style={{ marginTop: "34px", borderTop: "3px double #2B2318", paddingTop: "12px" }}>
            <div style={{ fontFamily: "'Libre Caslon Text', serif", fontSize: "17px", fontStyle: "italic", marginBottom: "8px" }}>Total geral</div>
            <div style={{ display: "flex", flexDirection: "column", gap: "4px", fontSize: "13px", alignItems: "flex-end" }}>
              <span style={{ color: "#2F5D50" }}>Revistas recebidas: <strong>{currency(grand.pago)}</strong></span>
              <span style={{ color: "#9B2C2C" }}>Revistas pendentes: <strong>{currency(grand.pendente)}</strong></span>
              <span>Ofertas: <strong>{currency(grand.ofertas)}</strong></span>
              <span>Doações: <strong>{currency(grand.doacoes)}</strong></span>
              <span style={{ fontSize: "15px", marginTop: "4px", borderTop: "1px solid rgba(43,35,24,0.3)", paddingTop: "4px" }}>
                Total arrecadado: <strong>{currency(grandConsolidado)}</strong>
              </span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default function App() {
  const [records, setRecords] = useState(null);
  const [editions, setEditions] = useState(null);
  const [finances, setFinances] = useState(null);
  const [tab, setTab] = useState(GROUPS[0]);
  const [modeView, setModeView] = useState("revistas"); // 'revistas' | 'ofertas'
  const [showForm, setShowForm] = useState(false);
  const [nome, setNome] = useState("");
  const [valor, setValor] = useState("");
  const [showEdForm, setShowEdForm] = useState(false);
  const [trimestre, setTrimestre] = useState("");
  const [capaPreview, setCapaPreview] = useState(null);
  const [showHistory, setShowHistory] = useState(false);
  const [saveError, setSaveError] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [reportMode, setReportMode] = useState(null); // null | 'edicao' | 'geral'
  const [showFinForm, setShowFinForm] = useState(false);
  const [finData, setFinData] = useState(lastOrThisSunday());
  const [finTipo, setFinTipo] = useState("oferta");
  const [finValor, setFinValor] = useState("");
  const [finDesc, setFinDesc] = useState("");
  const fileRef = useRef(null);

  useEffect(() => {
    (async () => {
      try {
        const r = await window.storage.get(REC_KEY, false);
        setRecords(r ? JSON.parse(r.value) : []);
      } catch {
        setRecords([]);
      }
      try {
        const e = await window.storage.get(ED_KEY, false);
        setEditions(e ? JSON.parse(e.value) : []);
      } catch {
        setEditions([]);
      }
      try {
        const f = await window.storage.get(FIN_KEY, false);
        setFinances(f ? JSON.parse(f.value) : []);
      } catch {
        setFinances([]);
      }
    })();
  }, []);

  async function persistRecords(next) {
    setRecords(next);
    try {
      const ok = await window.storage.set(REC_KEY, JSON.stringify(next), false);
      setSaveError(!ok);
    } catch {
      setSaveError(true);
    }
  }

  async function persistEditions(next) {
    setEditions(next);
    try {
      const ok = await window.storage.set(ED_KEY, JSON.stringify(next), false);
      setSaveError(!ok);
    } catch {
      setSaveError(true);
    }
  }

  async function persistFinances(next) {
    setFinances(next);
    try {
      const ok = await window.storage.set(FIN_KEY, JSON.stringify(next), false);
      setSaveError(!ok);
    } catch {
      setSaveError(true);
    }
  }

  const groupEditions = useMemo(
    () => (editions || []).filter((e) => e.grupo === tab).sort((a, b) => b.criadoEm.localeCompare(a.criadoEm)),
    [editions, tab]
  );
  const currentEdition = groupEditions[0] || null;
  const pastEditions = groupEditions.slice(1);

  function editionTotals(edId) {
    return editionTotalsOf(records || [], edId);
  }

  async function onPickFile(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    try {
      const dataUrl = await resizeImage(file);
      setCapaPreview(dataUrl);
    } catch {
      setSaveError(true);
    }
    setUploading(false);
  }

  function saveEdition(e) {
    e.preventDefault();
    if (!trimestre.trim()) return;
    const nova = {
      id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
      grupo: tab,
      trimestre: trimestre.trim(),
      capa: capaPreview,
      criadoEm: new Date().toISOString(),
    };
    persistEditions([nova, ...(editions || [])]);
    setTrimestre("");
    setCapaPreview(null);
    setShowEdForm(false);
  }

  function addRecord(e) {
    e.preventDefault();
    if (!nome.trim()) return;
    const novo = {
      id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
      nome: nome.trim(),
      grupo: tab,
      edicaoId: currentEdition ? currentEdition.id : null,
      valor: Number(valor) || 0,
      status: "pendente",
      data: new Date().toISOString(),
    };
    persistRecords([novo, ...(records || [])]);
    setNome("");
    setValor("");
    setShowForm(false);
  }

  function toggleStatus(id) {
    persistRecords((records || []).map((r) => (r.id === id ? { ...r, status: r.status === "pago" ? "pendente" : "pago" } : r)));
  }

  function removeRecord(id) {
    persistRecords((records || []).filter((r) => r.id !== id));
  }

  function addFinance(e) {
    e.preventDefault();
    const v = Number(finValor);
    if (!finData || !v || v <= 0) return;
    const novo = {
      id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
      grupo: tab,
      data: finData,
      tipo: finTipo,
      valor: v,
      descricao: finDesc.trim(),
      criadoEm: new Date().toISOString(),
    };
    persistFinances([novo, ...(finances || [])]);
    setFinValor("");
    setFinDesc("");
    setFinData(lastOrThisSunday());
    setShowFinForm(false);
  }

  function removeFinance(id) {
    persistFinances((finances || []).filter((f) => f.id !== id));
  }

  const currentRecords = useMemo(
    () => (records || []).filter((r) => r.grupo === tab && r.edicaoId === (currentEdition ? currentEdition.id : null)),
    [records, tab, currentEdition]
  );

  const totals = useMemo(() => {
    const base = currentEdition ? currentRecords : [];
    const pago = base.filter((r) => r.status === "pago").reduce((s, r) => s + r.valor, 0);
    const pendente = base.filter((r) => r.status === "pendente").reduce((s, r) => s + r.valor, 0);
    return { pago, pendente, total: pago + pendente };
  }, [currentRecords, currentEdition]);

  const groupFinances = useMemo(() => (finances || []).filter((f) => f.grupo === tab), [finances, tab]);
  const finTotals = useMemo(() => {
    const ofertas = groupFinances.filter((f) => f.tipo === "oferta").reduce((s, f) => s + f.valor, 0);
    const doacoes = groupFinances.filter((f) => f.tipo === "doacao").reduce((s, f) => s + f.valor, 0);
    return { ofertas, doacoes, total: ofertas + doacoes };
  }, [groupFinances]);

  const groupFinancesSorted = useMemo(
    () => [...groupFinances].sort((a, b) => b.data.localeCompare(a.data) || b.criadoEm.localeCompare(a.criadoEm)),
    [groupFinances]
  );

  if (records === null || editions === null || finances === null) {
    return (
      <div style={{ minHeight: "100vh", display: "flex", alignItems: "center", justifyContent: "center", background: "#F7F2E7", fontFamily: "'Inter', sans-serif", color: "#2B2318" }}>
        Abrindo o livro de registro…
      </div>
    );
  }

  if (reportMode) {
    return (
      <ReportView
        mode={reportMode}
        tab={tab}
        editions={editions}
        records={records}
        finances={finances}
        onClose={() => setReportMode(null)}
      />
    );
  }

  return (
    <div style={{ minHeight: "100vh", background: "#F7F2E7", fontFamily: "'Inter', sans-serif", color: "#2B2318" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Libre+Caslon+Text:ital,wght@0,400;0,700;1,400&family=Inter:wght@400;500;600;700&family=IBM+Plex+Mono:wght@500;600&display=swap');
        * { box-sizing: border-box; }
        body { margin: 0; }
        .tabbar::-webkit-scrollbar { display: none; }
        input:focus, select:focus { outline: 2px solid #2F5D50; outline-offset: 1px; }
        button:focus-visible { outline: 2px solid #2F5D50; outline-offset: 2px; }
        @media (prefers-reduced-motion: reduce) { * { transition: none !important; } }
      `}</style>

      <header style={{ padding: "28px 20px 18px", borderBottom: "1px solid rgba(43,35,24,0.15)", display: "flex", justifyContent: "space-between", alignItems: "flex-end", gap: "10px" }}>
        <div>
          <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: "11px", letterSpacing: "0.18em", textTransform: "uppercase", color: "#B8892B", marginBottom: "6px" }}>
            Escola Bíblica Dominical
          </div>
          <h1 style={{ fontFamily: "'Libre Caslon Text', serif", fontSize: "26px", fontStyle: "italic", fontWeight: 400, margin: 0, color: "#2B2318" }}>
            Livro de Registro
          </h1>
        </div>
        <button
          onClick={() => setReportMode("geral")}
          style={{ flexShrink: 0, padding: "8px 12px", borderRadius: "6px", border: "1px solid rgba(43,35,24,0.25)", background: "#FFFDF8", color: "#2B2318", fontSize: "12px", fontWeight: 700, cursor: "pointer" }}
        >
          Relatório geral
        </button>
      </header>

      <div style={{ display: "flex", gap: "8px", padding: "14px 20px 0" }}>
        {[
          { key: "revistas", label: "Revistas" },
          { key: "ofertas", label: "Ofertas & Doações" },
        ].map((m) => (
          <button
            key={m.key}
            onClick={() => setModeView(m.key)}
            style={{
              flex: 1,
              padding: "9px",
              borderRadius: "8px",
              border: `1px solid ${modeView === m.key ? "#2B2318" : "rgba(43,35,24,0.2)"}`,
              background: modeView === m.key ? "#2B2318" : "#FFFDF8",
              color: modeView === m.key ? "#F7F2E7" : "#2B2318",
              fontSize: "13px",
              fontWeight: 700,
              cursor: "pointer",
            }}
          >
            {m.label}
          </button>
        ))}
      </div>

      <nav className="tabbar" style={{ display: "flex", gap: "8px", overflowX: "auto", padding: "14px 20px", borderBottom: "1px solid rgba(43,35,24,0.1)" }}>
        {GROUPS.map((g) => (
          <button
            key={g}
            onClick={() => { setTab(g); setShowHistory(false); setShowForm(false); setShowEdForm(false); setShowFinForm(false); }}
            style={{
              flexShrink: 0,
              padding: "7px 14px",
              borderRadius: "999px",
              border: `1px solid ${tab === g ? "#2F5D50" : "rgba(43,35,24,0.2)"}`,
              background: tab === g ? "#2F5D50" : "transparent",
              color: tab === g ? "#F7F2E7" : "#2B2318",
              fontSize: "13px",
              fontWeight: 600,
              cursor: "pointer",
              whiteSpace: "nowrap",
            }}
          >
            {g}
          </button>
        ))}
      </nav>

      {modeView === "revistas" ? (
        <main style={{ padding: "16px 20px 100px" }}>
          {!currentEdition ? (
            <div style={{ background: "#FFFDF8", border: "1px dashed rgba(43,35,24,0.3)", borderRadius: "10px", padding: "18px", textAlign: "center" }}>
              <div style={{ fontSize: "14px", color: "#8B8378", marginBottom: "10px" }}>
                Nenhuma revista cadastrada para {tab} ainda.
              </div>
              <button
                onClick={() => setShowEdForm(true)}
                style={{ padding: "10px 16px", borderRadius: "6px", border: "none", background: "#2F5D50", color: "#F7F2E7", fontWeight: 700, cursor: "pointer" }}
              >
                Cadastrar revista do trimestre
              </button>
            </div>
          ) : (
            <div style={{ background: "#FFFDF8", border: "1px solid rgba(43,35,24,0.12)", borderRadius: "10px", padding: "14px", display: "flex", gap: "14px" }}>
              {currentEdition.capa ? (
                <img src={currentEdition.capa} alt={`Capa ${currentEdition.trimestre}`} style={{ width: "76px", height: "104px", objectFit: "cover", borderRadius: "4px", border: "1px solid rgba(43,35,24,0.15)" }} />
              ) : (
                <div style={{ width: "76px", height: "104px", borderRadius: "4px", border: "1px dashed rgba(43,35,24,0.25)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "10px", color: "#8B8378", textAlign: "center", padding: "4px" }}>
                  sem capa
                </div>
              )}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: "10px", textTransform: "uppercase", letterSpacing: "0.08em", color: "#B8892B", fontWeight: 700 }}>{tab}</div>
                <div style={{ fontFamily: "'Libre Caslon Text', serif", fontSize: "18px", margin: "2px 0 8px" }}>{currentEdition.trimestre}</div>
                <div style={{ display: "flex", gap: "10px", flexWrap: "wrap", fontSize: "12px" }}>
                  <span style={{ color: "#2F5D50", fontWeight: 600 }}>{currency(totals.pago)} recebido</span>
                  <span style={{ color: "#9B2C2C", fontWeight: 600 }}>{currency(totals.pendente)} pendente</span>
                </div>
                <div style={{ display: "flex", gap: "14px", marginTop: "8px" }}>
                  <button onClick={() => setShowEdForm(true)} style={{ border: "none", background: "none", color: "#8B8378", fontSize: "12px", textDecoration: "underline", cursor: "pointer", padding: 0 }}>
                    Novo trimestre
                  </button>
                  <button onClick={() => setReportMode("edicao")} style={{ border: "none", background: "none", color: "#2F5D50", fontSize: "12px", fontWeight: 700, textDecoration: "underline", cursor: "pointer", padding: 0 }}>
                    Relatório deste trimestre
                  </button>
                </div>
              </div>
            </div>
          )}

          {showEdForm && (
            <form onSubmit={saveEdition} style={{ marginTop: "12px", background: "#FFFDF8", border: "1px solid rgba(43,35,24,0.15)", borderRadius: "10px", padding: "14px", display: "flex", flexDirection: "column", gap: "10px" }}>
              {BETEL_CATALOG[tab] && (
                <button
                  type="button"
                  onClick={() => {
                    setTrimestre(`${BETEL_CATALOG[tab].revista} — ${BETEL_CATALOG[tab].trimestre}`);
                    setCapaPreview(BETEL_CATALOG[tab].capa);
                  }}
                  style={{ display: "flex", alignItems: "center", gap: "10px", padding: "8px", borderRadius: "6px", border: "1px solid #B8892B", background: "rgba(184,137,39,0.08)", cursor: "pointer", textAlign: "left" }}
                >
                  <img src={BETEL_CATALOG[tab].capa} alt="" style={{ width: "34px", height: "46px", objectFit: "cover", borderRadius: "3px" }} />
                  <span style={{ fontSize: "12px", color: "#2B2318" }}>
                    <strong>Usar capa oficial Betel</strong><br />
                    {BETEL_CATALOG[tab].revista} · {BETEL_CATALOG[tab].trimestre}
                  </span>
                </button>
              )}
              <input
                autoFocus
                placeholder='Trimestre (ex: 3º Trimestre 2026)'
                value={trimestre}
                onChange={(e) => setTrimestre(e.target.value)}
                style={{ padding: "10px 12px", borderRadius: "6px", border: "1px solid rgba(43,35,24,0.2)", fontSize: "14px", fontFamily: "inherit" }}
              />
              <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                {capaPreview && (
                  <img src={capaPreview} alt="Pré-visualização da capa" style={{ width: "50px", height: "68px", objectFit: "cover", borderRadius: "4px", border: "1px solid rgba(43,35,24,0.15)" }} />
                )}
                <button
                  type="button"
                  onClick={() => fileRef.current?.click()}
                  style={{ flex: 1, padding: "10px 12px", borderRadius: "6px", border: "1px solid rgba(43,35,24,0.2)", background: "#fff", fontSize: "13px", cursor: "pointer" }}
                >
                  {uploading ? "Carregando…" : capaPreview ? "Trocar foto da capa" : "Adicionar foto da capa"}
                </button>
                <input ref={fileRef} type="file" accept="image/*" capture="environment" onChange={onPickFile} style={{ display: "none" }} />
              </div>
              <div style={{ display: "flex", gap: "10px" }}>
                <button
                  type="button"
                  onClick={() => { setShowEdForm(false); setTrimestre(""); setCapaPreview(null); }}
                  style={{ flex: 1, padding: "11px", borderRadius: "6px", border: "1px solid rgba(43,35,24,0.2)", background: "transparent", color: "#2B2318", fontWeight: 600, cursor: "pointer" }}
                >
                  Cancelar
                </button>
                <button
                  type="submit"
                  style={{ flex: 2, padding: "11px", borderRadius: "6px", border: "none", background: "#2F5D50", color: "#F7F2E7", fontWeight: 700, cursor: "pointer" }}
                >
                  Salvar revista
                </button>
              </div>
            </form>
          )}

          {currentEdition && (
            <div style={{ marginTop: "16px" }}>
              {currentRecords.length === 0 ? (
                <div style={{ textAlign: "center", padding: "36px 20px", color: "#8B8378", fontSize: "14px" }}>
                  Nenhuma entrega registrada para este trimestre ainda.
                </div>
              ) : (
                currentRecords.map((r, i) => (
                  <div
                    key={r.id}
                    style={{
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "space-between",
                      gap: "10px",
                      padding: "12px 4px",
                      borderBottom: i === currentRecords.length - 1 ? "none" : "1px dashed rgba(43,35,24,0.18)",
                    }}
                  >
                    <div style={{ minWidth: 0, flex: 1 }}>
                      <div style={{ fontWeight: 600, fontSize: "15px", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{r.nome}</div>
                      <div style={{ fontSize: "12px", color: "#8B8378", marginTop: "2px", fontFamily: "'IBM Plex Mono', monospace" }}>{currency(r.valor)}</div>
                    </div>
                    <Stamp status={r.status} onClick={() => toggleStatus(r.id)} />
                    <button onClick={() => removeRecord(r.id)} aria-label={`Remover ${r.nome}`} style={{ border: "none", background: "none", color: "#8B8378", fontSize: "18px", cursor: "pointer", padding: "4px 6px", lineHeight: 1 }}>×</button>
                  </div>
                ))
              )}
            </div>
          )}

          {pastEditions.length > 0 && (
            <div style={{ marginTop: "20px" }}>
              <button
                onClick={() => setShowHistory((v) => !v)}
                style={{ border: "none", background: "none", color: "#8B8378", fontSize: "12px", fontWeight: 600, textDecoration: "underline", cursor: "pointer", padding: 0 }}
              >
                {showHistory ? "Ocultar" : "Ver"} trimestres anteriores de {tab} ({pastEditions.length})
              </button>
              {showHistory && (
                <div style={{ marginTop: "10px", display: "flex", flexDirection: "column", gap: "10px" }}>
                  {pastEditions.map((ed) => {
                    const t = editionTotals(ed.id);
                    return (
                      <div key={ed.id} style={{ display: "flex", gap: "12px", background: "#FFFDF8", border: "1px solid rgba(43,35,24,0.1)", borderRadius: "8px", padding: "10px" }}>
                        {ed.capa ? (
                          <img src={ed.capa} alt={ed.trimestre} style={{ width: "44px", height: "60px", objectFit: "cover", borderRadius: "3px" }} />
                        ) : (
                          <div style={{ width: "44px", height: "60px", border: "1px dashed rgba(43,35,24,0.25)", borderRadius: "3px" }} />
                        )}
                        <div style={{ flex: 1 }}>
                          <div style={{ fontSize: "13px", fontWeight: 600 }}>{ed.trimestre}</div>
                          <div style={{ fontSize: "11px", color: "#8B8378", marginTop: "2px" }}>{t.count} entrega(s)</div>
                          <div style={{ fontSize: "11px", marginTop: "2px" }}>
                            <span style={{ color: "#2F5D50", fontWeight: 600 }}>{currency(t.pago)}</span>{" · "}
                            <span style={{ color: "#9B2C2C", fontWeight: 600 }}>{currency(t.pendente)} pend.</span>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}
        </main>
      ) : (
        <main style={{ padding: "16px 20px 100px" }}>
          <div style={{ background: "#FFFDF8", border: "1px solid rgba(43,35,24,0.12)", borderRadius: "10px", padding: "14px" }}>
            <div style={{ fontSize: "10px", textTransform: "uppercase", letterSpacing: "0.08em", color: "#B8892B", fontWeight: 700 }}>{tab}</div>
            <div style={{ fontFamily: "'Libre Caslon Text', serif", fontSize: "18px", margin: "2px 0 8px" }}>Ofertas e doações</div>
            <div style={{ display: "flex", gap: "16px", flexWrap: "wrap", fontSize: "12px" }}>
              <span style={{ fontWeight: 600 }}>{currency(finTotals.ofertas)} em ofertas</span>
              <span style={{ fontWeight: 600 }}>{currency(finTotals.doacoes)} em doações</span>
              <span style={{ fontWeight: 700, color: "#2F5D50" }}>{currency(finTotals.total)} no total</span>
            </div>
          </div>

          {!showFinForm ? (
            <button
              onClick={() => setShowFinForm(true)}
              style={{ marginTop: "12px", width: "100%", padding: "12px", borderRadius: "8px", border: "none", background: "#2F5D50", color: "#F7F2E7", fontSize: "14px", fontWeight: 700, cursor: "pointer" }}
            >
              + Lançar oferta ou doação
            </button>
          ) : (
            <form onSubmit={addFinance} style={{ marginTop: "12px", background: "#FFFDF8", border: "1px solid rgba(43,35,24,0.15)", borderRadius: "10px", padding: "14px", display: "flex", flexDirection: "column", gap: "10px" }}>
              <div style={{ display: "flex", gap: "10px" }}>
                <input
                  type="date"
                  value={finData}
                  onChange={(e) => setFinData(e.target.value)}
                  style={{ flex: 1, padding: "10px 12px", borderRadius: "6px", border: "1px solid rgba(43,35,24,0.2)", fontSize: "14px", fontFamily: "inherit" }}
                />
                <select
                  value={finTipo}
                  onChange={(e) => setFinTipo(e.target.value)}
                  style={{ flex: 1, padding: "10px 12px", borderRadius: "6px", border: "1px solid rgba(43,35,24,0.2)", fontSize: "14px", fontFamily: "inherit", background: "#fff" }}
                >
                  <option value="oferta">Oferta do dia</option>
                  <option value="doacao">Doação</option>
                </select>
              </div>
              <input
                type="number"
                step="0.01"
                min="0"
                placeholder="Valor (R$)"
                value={finValor}
                onChange={(e) => setFinValor(e.target.value)}
                style={{ padding: "10px 12px", borderRadius: "6px", border: "1px solid rgba(43,35,24,0.2)", fontSize: "14px", fontFamily: "'IBM Plex Mono', monospace" }}
              />
              <input
                placeholder={finTipo === "doacao" ? "De quem / para quê (opcional)" : "Observação (opcional)"}
                value={finDesc}
                onChange={(e) => setFinDesc(e.target.value)}
                style={{ padding: "10px 12px", borderRadius: "6px", border: "1px solid rgba(43,35,24,0.2)", fontSize: "14px", fontFamily: "inherit" }}
              />
              <div style={{ display: "flex", gap: "10px" }}>
                <button type="button" onClick={() => setShowFinForm(false)} style={{ flex: 1, padding: "11px", borderRadius: "6px", border: "1px solid rgba(43,35,24,0.2)", background: "transparent", color: "#2B2318", fontWeight: 600, cursor: "pointer" }}>
                  Cancelar
                </button>
                <button type="submit" style={{ flex: 2, padding: "11px", borderRadius: "6px", border: "none", background: "#2F5D50", color: "#F7F2E7", fontWeight: 700, cursor: "pointer" }}>
                  Lançar
                </button>
              </div>
            </form>
          )}

          <div style={{ marginTop: "18px" }}>
            {groupFinancesSorted.length === 0 ? (
              <div style={{ textAlign: "center", padding: "36px 20px", color: "#8B8378", fontSize: "14px" }}>
                Nenhuma oferta ou doação lançada ainda para {tab}.
              </div>
            ) : (
              groupFinancesSorted.map((f, i) => (
                <div
                  key={f.id}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "space-between",
                    gap: "10px",
                    padding: "12px 4px",
                    borderBottom: i === groupFinancesSorted.length - 1 ? "none" : "1px dashed rgba(43,35,24,0.18)",
                  }}
                >
                  <div style={{ minWidth: 0, flex: 1 }}>
                    <div style={{ fontWeight: 600, fontSize: "14px", textTransform: "capitalize" }}>{formatDayDate(f.data)}</div>
                    <div style={{ fontSize: "12px", color: "#8B8378", marginTop: "2px" }}>
                      {f.tipo === "oferta" ? "Oferta" : "Doação"}{f.descricao ? ` · ${f.descricao}` : ""}
                    </div>
                  </div>
                  <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: "14px", fontWeight: 700, color: f.tipo === "oferta" ? "#2F5D50" : "#B8892B" }}>
                    {currency(f.valor)}
                  </div>
                  <button onClick={() => removeFinance(f.id)} aria-label="Remover lançamento" style={{ border: "none", background: "none", color: "#8B8378", fontSize: "18px", cursor: "pointer", padding: "4px 6px", lineHeight: 1 }}>×</button>
                </div>
              ))
            )}
          </div>
        </main>
      )}

      {saveError && (
        <div style={{ position: "fixed", bottom: "84px", left: "20px", right: "20px", background: "#9B2C2C", color: "#fff", padding: "10px 14px", borderRadius: "6px", fontSize: "13px", textAlign: "center" }}>
          Não foi possível salvar agora. Tente novamente.
        </div>
      )}

      {modeView === "revistas" && currentEdition && (
        <div style={{ position: "fixed", bottom: 0, left: 0, right: 0, padding: "14px 20px", background: "linear-gradient(to top, #F7F2E7 60%, transparent)" }}>
          {!showForm ? (
            <button
              onClick={() => setShowForm(true)}
              style={{ width: "100%", padding: "14px", borderRadius: "8px", border: "none", background: "#2F5D50", color: "#F7F2E7", fontSize: "15px", fontWeight: 700, cursor: "pointer" }}
            >
              + Nova entrega ({tab})
            </button>
          ) : (
            <form onSubmit={addRecord} style={{ background: "#FFFDF8", border: "1px solid rgba(43,35,24,0.15)", borderRadius: "10px", padding: "14px", display: "flex", flexDirection: "column", gap: "10px" }}>
              <input
                autoFocus
                placeholder="Nome da pessoa"
                value={nome}
                onChange={(e) => setNome(e.target.value)}
                style={{ padding: "10px 12px", borderRadius: "6px", border: "1px solid rgba(43,35,24,0.2)", fontSize: "14px", fontFamily: "inherit" }}
              />
              <input
                type="number"
                step="0.01"
                min="0"
                placeholder="Valor (R$)"
                value={valor}
                onChange={(e) => setValor(e.target.value)}
                style={{ padding: "10px 12px", borderRadius: "6px", border: "1px solid rgba(43,35,24,0.2)", fontSize: "14px", fontFamily: "'IBM Plex Mono', monospace" }}
              />
              <div style={{ display: "flex", gap: "10px" }}>
                <button type="button" onClick={() => setShowForm(false)} style={{ flex: 1, padding: "11px", borderRadius: "6px", border: "1px solid rgba(43,35,24,0.2)", background: "transparent", color: "#2B2318", fontWeight: 600, cursor: "pointer" }}>
                  Cancelar
                </button>
                <button type="submit" style={{ flex: 2, padding: "11px", borderRadius: "6px", border: "none", background: "#2F5D50", color: "#F7F2E7", fontWeight: 700, cursor: "pointer" }}>
                  Registrar entrega
                </button>
              </div>
            </form>
          )}
        </div>
      )}
    </div>
  );
}
