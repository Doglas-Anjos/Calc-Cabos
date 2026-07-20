import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { api } from '../api/client';
import {
  NUMERO_CONDUTORES_PARALELOS_MAX_ABSOLUTO,
  NUMERO_CONDUTORES_PARALELOS_MIN_ABSOLUTO,
  type Circuito,
  type CircuitoInput,
  type FatorAgrupamentoTipo,
} from '@shared/index';

interface CatalogoOptionRow {
  id: number;
  [key: string]: unknown;
}

const CAMPOS_NUMERICOS: (keyof CircuitoInput)[] = [
  'tipoCargaId',
  'metodoInstalacaoId',
  'tipoCircuitoId',
  'categoriaCaboId',
  'produtoComercialId',
  'materialCondutorId',
  'temperaturaAmbienteC',
  'fatorAgrupamentoId',
  'comprimentoM',
  'tensaoNominalV',
  'correnteA',
  'fatorPotencia',
  'correnteCurtoCircuitoA',
  'tempoAtuacaoCurtoCircuitoS',
  'quedaTensaoNominalMaxPct',
  'quedaTensaoPartidaMaxPct',
  'fatorPotenciaPartida',
  'correntePartidaA',
  'numeroCondutoresParalelosMin',
  'numeroCondutoresParalelosMax',
];

const OPCOES_NUMERO_CONDUTORES_PARALELOS = Array.from(
  { length: NUMERO_CONDUTORES_PARALELOS_MAX_ABSOLUTO - NUMERO_CONDUTORES_PARALELOS_MIN_ABSOLUTO + 1 },
  (_, i) => NUMERO_CONDUTORES_PARALELOS_MIN_ABSOLUTO + i,
);

const vazio: Partial<CircuitoInput> = {
  nome: '',
  fatorAgrupamentoTipo: 'ar',
  numeroCondutoresParalelosMin: NUMERO_CONDUTORES_PARALELOS_MIN_ABSOLUTO,
  numeroCondutoresParalelosMax: NUMERO_CONDUTORES_PARALELOS_MAX_ABSOLUTO,
};

export function CircuitoFormPage() {
  const { projetoId: projetoIdParam, circuitoId } = useParams();
  const isEdit = Boolean(circuitoId);
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const [form, setForm] = useState<Partial<CircuitoInput>>(vazio);
  const [erro, setErro] = useState<string | null>(null);

  const { data: circuitoExistente } = useQuery({
    queryKey: ['circuitos', circuitoId],
    queryFn: async () => (await api.get<Circuito>(`/circuitos/${circuitoId}`)).data,
    enabled: isEdit,
  });

  const projetoId = isEdit ? circuitoExistente?.projetoId : Number(projetoIdParam);

  useEffect(() => {
    if (circuitoExistente) setForm(circuitoExistente);
  }, [circuitoExistente]);

  const { data: tiposCarga } = useQuery({
    queryKey: ['tipos-carga'],
    queryFn: async () => (await api.get<CatalogoOptionRow[]>('/tipos-carga')).data,
  });
  const { data: tiposCircuito } = useQuery({
    queryKey: ['catalogo-bt', 'tipos-circuito'],
    queryFn: async () => (await api.get<CatalogoOptionRow[]>('/catalogo-bt/tipos-circuito')).data,
  });
  const { data: metodosInstalacao } = useQuery({
    queryKey: ['catalogo-bt', 'metodos-instalacao'],
    queryFn: async () => (await api.get<CatalogoOptionRow[]>('/catalogo-bt/metodos-instalacao')).data,
  });
  const { data: categoriasCabo } = useQuery({
    queryKey: ['catalogo-bt', 'categorias-cabo'],
    queryFn: async () => (await api.get<CatalogoOptionRow[]>('/catalogo-bt/categorias-cabo')).data,
  });
  const { data: produtosComerciais } = useQuery({
    queryKey: ['catalogo-bt', 'produtos-comerciais'],
    queryFn: async () => (await api.get<CatalogoOptionRow[]>('/catalogo-bt/produtos-comerciais')).data,
  });
  const { data: materiaisCondutor } = useQuery({
    queryKey: ['catalogo-bt', 'materiais-condutor'],
    queryFn: async () => (await api.get<CatalogoOptionRow[]>('/catalogo-bt/materiais-condutor')).data,
  });
  const { data: fatoresAgrupamento } = useQuery({
    queryKey: ['catalogo-bt', 'fatores-agrupamento', form.fatorAgrupamentoTipo],
    queryFn: async () =>
      (await api.get<CatalogoOptionRow[]>('/catalogo-bt/fatores-agrupamento', { params: { tipo: form.fatorAgrupamentoTipo } })).data,
    enabled: Boolean(form.fatorAgrupamentoTipo),
  });
  const { data: temperaturas } = useQuery({
    queryKey: ['catalogo-bt', 'temperaturas', form.produtoComercialId, form.fatorAgrupamentoTipo],
    queryFn: async () =>
      (
        await api.get<{ temperatura_c: number }[]>('/catalogo-bt/temperaturas', {
          params: { produtoComercialId: form.produtoComercialId, fatorAgrupamentoTipo: form.fatorAgrupamentoTipo },
        })
      ).data,
    enabled: Boolean(form.produtoComercialId && form.fatorAgrupamentoTipo),
  });

  const isMotor = tiposCarga?.find((t) => t.id === form.tipoCargaId)?.nome === 'Motor';

  const salvar = useMutation({
    mutationFn: async () => {
      const payload = { ...form };
      if (!isMotor) {
        delete payload.quedaTensaoPartidaMaxPct;
        delete payload.fatorPotenciaPartida;
        delete payload.correntePartidaA;
      }
      if (isEdit) {
        return (await api.patch<Circuito>(`/circuitos/${circuitoId}`, payload)).data;
      }
      return (await api.post<Circuito>(`/projetos/${projetoId}/circuitos`, payload)).data;
    },
    onSuccess: (data) => {
      setErro(null);
      setForm(data);
      queryClient.invalidateQueries({ queryKey: ['projetos', String(projetoId), 'circuitos'] });
      if (!isEdit) navigate(`/circuitos/${data.id}`, { replace: true });
    },
    onError: (err: any) => setErro(err?.response?.data?.message ?? 'Erro ao calcular circuito'),
  });

  function setCampo<K extends keyof CircuitoInput>(campo: K, valor: string) {
    const numerico = CAMPOS_NUMERICOS.includes(campo);
    setForm((f) => ({ ...f, [campo]: numerico ? (valor === '' ? undefined : Number(valor)) : valor }));
  }

  const resultado = salvar.data?.resultadoAtual ?? circuitoExistente?.resultadoAtual;

  return (
    <div>
      <p>
        <Link to={projetoId ? `/projetos/${projetoId}` : '/'}>&larr; Voltar ao projeto</Link>
      </p>
      <h1>{isEdit ? 'Editar circuito' : 'Novo circuito'}</h1>

      <div className="card">
        <div className="form-grid">
          <div className="field">
            <label>Nome do circuito</label>
            <input value={form.nome ?? ''} onChange={(e) => setCampo('nome', e.target.value)} />
          </div>

          <div className="field">
            <label>Tipo de carga</label>
            <select value={form.tipoCargaId ?? ''} onChange={(e) => setCampo('tipoCargaId', e.target.value)}>
              <option value="">Selecione...</option>
              {tiposCarga?.map((o) => (
                <option key={o.id} value={o.id}>
                  {String(o.nome)}
                </option>
              ))}
            </select>
          </div>

          <div className="field">
            <label>Sistema (tipo de circuito)</label>
            <select value={form.tipoCircuitoId ?? ''} onChange={(e) => setCampo('tipoCircuitoId', e.target.value)}>
              <option value="">Selecione...</option>
              {tiposCircuito?.map((o) => (
                <option key={o.id} value={o.id}>
                  {String(o.codigo)}
                </option>
              ))}
            </select>
          </div>

          <div className="field">
            <label>Maneira de instalar</label>
            <select value={form.metodoInstalacaoId ?? ''} onChange={(e) => setCampo('metodoInstalacaoId', e.target.value)}>
              <option value="">Selecione...</option>
              {metodosInstalacao?.map((o) => (
                <option key={o.id} value={o.id}>
                  {String(o.tipo_linha_eletrica)}
                </option>
              ))}
            </select>
          </div>

          <div className="field">
            <label>Tipo do cabo</label>
            <select value={form.categoriaCaboId ?? ''} onChange={(e) => setCampo('categoriaCaboId', e.target.value)}>
              <option value="">Selecione...</option>
              {categoriasCabo?.map((o) => (
                <option key={o.id} value={o.id}>
                  {String(o.nome)}
                </option>
              ))}
            </select>
          </div>

          <div className="field">
            <label>Cabo</label>
            <select value={form.produtoComercialId ?? ''} onChange={(e) => setCampo('produtoComercialId', e.target.value)}>
              <option value="">Selecione...</option>
              {produtosComerciais?.map((o) => (
                <option key={o.id} value={o.id}>
                  {String(o.fabricante)} — {String(o.nome_comercial)}
                </option>
              ))}
            </select>
          </div>

          <div className="field">
            <label>Material do condutor</label>
            <select value={form.materialCondutorId ?? ''} onChange={(e) => setCampo('materialCondutorId', e.target.value)}>
              <option value="">Selecione...</option>
              {materiaisCondutor?.map((o) => (
                <option key={o.id} value={o.id}>
                  {String(o.nome)}
                </option>
              ))}
            </select>
          </div>

          <div className="field">
            <label>Instalação (para agrupamento e temperatura)</label>
            <select
              value={form.fatorAgrupamentoTipo ?? 'ar'}
              onChange={(e) => setCampo('fatorAgrupamentoTipo', e.target.value as FatorAgrupamentoTipo)}
            >
              <option value="ar">Ao ar</option>
              <option value="enterrado">Enterrado</option>
            </select>
          </div>

          <div className="field">
            <label>Temperatura ambiente (°C)</label>
            <select value={form.temperaturaAmbienteC ?? ''} onChange={(e) => setCampo('temperaturaAmbienteC', e.target.value)}>
              <option value="">Selecione...</option>
              {temperaturas?.map((o) => (
                <option key={o.temperatura_c} value={o.temperatura_c}>
                  {o.temperatura_c}
                </option>
              ))}
            </select>
          </div>

          <div className="field">
            <label>Fator de agrupamento</label>
            <select value={form.fatorAgrupamentoId ?? ''} onChange={(e) => setCampo('fatorAgrupamentoId', e.target.value)}>
              <option value="">Selecione...</option>
              {fatoresAgrupamento?.map((o) => (
                <option key={o.id} value={o.id}>
                  {String(o.cenario)} — fator {String(o.fator)}
                </option>
              ))}
            </select>
          </div>

          <div className="field">
            <label>Condutores em paralelo por fase — mínimo</label>
            <select
              value={form.numeroCondutoresParalelosMin ?? NUMERO_CONDUTORES_PARALELOS_MIN_ABSOLUTO}
              onChange={(e) => setCampo('numeroCondutoresParalelosMin', e.target.value)}
            >
              {OPCOES_NUMERO_CONDUTORES_PARALELOS.map((n) => (
                <option key={n} value={n}>
                  {n}
                </option>
              ))}
            </select>
          </div>

          <div className="field">
            <label>Condutores em paralelo por fase — máximo</label>
            <select
              value={form.numeroCondutoresParalelosMax ?? NUMERO_CONDUTORES_PARALELOS_MAX_ABSOLUTO}
              onChange={(e) => setCampo('numeroCondutoresParalelosMax', e.target.value)}
            >
              {OPCOES_NUMERO_CONDUTORES_PARALELOS.map((n) => (
                <option key={n} value={n}>
                  {n}
                </option>
              ))}
            </select>
          </div>

          <div className="field">
            <label>Comprimento do cabo (m)</label>
            <input type="number" value={form.comprimentoM ?? ''} onChange={(e) => setCampo('comprimentoM', e.target.value)} />
          </div>

          <div className="field">
            <label>Tensão nominal (V)</label>
            <input type="number" value={form.tensaoNominalV ?? ''} onChange={(e) => setCampo('tensaoNominalV', e.target.value)} />
          </div>

          <div className="field">
            <label>Corrente (A)</label>
            <input type="number" value={form.correnteA ?? ''} onChange={(e) => setCampo('correnteA', e.target.value)} />
          </div>

          <div className="field">
            <label>Fator de potência</label>
            <input type="number" step="0.01" value={form.fatorPotencia ?? ''} onChange={(e) => setCampo('fatorPotencia', e.target.value)} />
          </div>

          <div className="field">
            <label>Corrente de curto-circuito (A)</label>
            <input type="number" value={form.correnteCurtoCircuitoA ?? ''} onChange={(e) => setCampo('correnteCurtoCircuitoA', e.target.value)} />
          </div>

          <div className="field">
            <label>Tempo de atuação do curto-circuito (s)</label>
            <input
              type="number"
              step="0.01"
              value={form.tempoAtuacaoCurtoCircuitoS ?? ''}
              onChange={(e) => setCampo('tempoAtuacaoCurtoCircuitoS', e.target.value)}
            />
          </div>

          <div className="field">
            <label>Queda de tensão nominal máxima (%)</label>
            <input
              type="number"
              step="0.1"
              value={form.quedaTensaoNominalMaxPct ?? ''}
              onChange={(e) => setCampo('quedaTensaoNominalMaxPct', e.target.value)}
            />
          </div>

          {isMotor && (
            <>
              <div className="field">
                <label>Queda de tensão na partida máxima (%)</label>
                <input
                  type="number"
                  step="0.1"
                  value={form.quedaTensaoPartidaMaxPct ?? ''}
                  onChange={(e) => setCampo('quedaTensaoPartidaMaxPct', e.target.value)}
                />
              </div>
              <div className="field">
                <label>Fator de potência na partida</label>
                <input
                  type="number"
                  step="0.01"
                  value={form.fatorPotenciaPartida ?? ''}
                  onChange={(e) => setCampo('fatorPotenciaPartida', e.target.value)}
                />
              </div>
              <div className="field">
                <label>Corrente de partida (A)</label>
                <input
                  type="number"
                  value={form.correntePartidaA ?? ''}
                  onChange={(e) => setCampo('correntePartidaA', e.target.value)}
                />
              </div>
            </>
          )}
        </div>

        {erro && <div className="error-msg">{erro}</div>}
        <button disabled={salvar.isPending} onClick={() => salvar.mutate()}>
          {isEdit ? 'Recalcular' : 'Calcular e salvar'}
        </button>
      </div>

      {resultado && (
        <div className="card">
          <h2>
            Resultado{' '}
            <span className={`badge ${resultado.viavel ? 'ok' : 'fail'}`}>{resultado.viavel ? 'viável' : 'inviável'}</span>
          </h2>
          {resultado.viavel ? (
            <ul>
              <li>
                Seção calculada: {resultado.secaoCalculadaMm2} mm²
                {resultado.numeroCondutoresParalelosCalculado != null &&
                  resultado.numeroCondutoresParalelosCalculado > 1 &&
                  ` × ${resultado.numeroCondutoresParalelosCalculado} condutores em paralelo por fase`}
              </li>
              <li>Corrente admissível corrigida (por condutor): {resultado.correnteAdmissivelCorrigidaA} A</li>
              <li>Queda de tensão calculada: {Number(resultado.quedaTensaoCalculadaPct).toFixed(2)}%</li>
              {resultado.quedaTensaoPartidaCalculadaPct != null && (
                <li>Queda de tensão na partida: {Number(resultado.quedaTensaoPartidaCalculadaPct).toFixed(2)}%</li>
              )}
              <li>Seção mínima por curto-circuito: {resultado.secaoMinimaCurtoCircuitoMm2} mm²</li>
            </ul>
          ) : (
            <p>{String((resultado.memoriaCalculo as any)?.motivo)}</p>
          )}
          <details>
            <summary>Memória de cálculo</summary>
            <pre className="memoria">{JSON.stringify(resultado.memoriaCalculo, null, 2)}</pre>
          </details>
        </div>
      )}
    </div>
  );
}
