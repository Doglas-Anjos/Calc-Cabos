import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { api } from '../api/client';
import type { Circuito, Projeto } from '@shared/index';

export function ProjetoDetailPage() {
  const { projetoId } = useParams();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [erroImportacao, setErroImportacao] = useState<string | null>(null);

  const { data: projeto } = useQuery({
    queryKey: ['projetos', projetoId],
    queryFn: async () => (await api.get<Projeto>(`/projetos/${projetoId}`)).data,
  });

  const { data: circuitos, isLoading } = useQuery({
    queryKey: ['projetos', projetoId, 'circuitos'],
    queryFn: async () => (await api.get<Circuito[]>(`/projetos/${projetoId}/circuitos`)).data,
  });

  const importar = useMutation({
    mutationFn: async (arquivo: File) => {
      const formData = new FormData();
      formData.append('arquivo', arquivo);
      return (
        await api.post<{ importJobId: number }>(`/projetos/${projetoId}/circuitos/importar`, formData, {
          headers: { 'Content-Type': 'multipart/form-data' },
        })
      ).data;
    },
    onSuccess: (data) => navigate(`/import-jobs/${data.importJobId}`),
    onError: (err: any) => setErroImportacao(err?.response?.data?.message ?? 'Erro ao importar'),
  });

  return (
    <div>
      <p>
        <Link to="/">&larr; Projetos</Link>
      </p>
      <h1>{projeto?.nome}</h1>
      {projeto?.descricao && <p>{projeto.descricao}</p>}

      <div className="card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <h2 style={{ margin: 0 }}>Circuitos</h2>
          <div style={{ display: 'flex', gap: '0.5rem' }}>
            <input
              ref={fileInputRef}
              type="file"
              accept=".xlsx,.xls"
              style={{ display: 'none' }}
              onChange={(e) => {
                const arquivo = e.target.files?.[0];
                if (arquivo) importar.mutate(arquivo);
                e.target.value = '';
              }}
            />
            <button className="secondary" onClick={() => fileInputRef.current?.click()} disabled={importar.isPending}>
              Importar Excel
            </button>
            <Link to={`/projetos/${projetoId}/circuitos/novo`}>
              <button>Novo circuito</button>
            </Link>
          </div>
        </div>
        {erroImportacao && <div className="error-msg">{erroImportacao}</div>}

        {isLoading && <p>Carregando...</p>}
        {circuitos?.length === 0 && <p>Nenhum circuito ainda.</p>}
        {circuitos?.map((c) => (
          <Link key={c.id} className="list-item" to={`/circuitos/${c.id}`}>
            {c.nome}{' '}
            {c.resultadoAtual && (
              <span className={`badge ${c.resultadoAtual.viavel ? 'ok' : 'fail'}`}>
                {c.resultadoAtual.viavel
                  ? `${c.resultadoAtual.secaoCalculadaMm2} mm²${
                      c.resultadoAtual.numeroCondutoresParalelosCalculado && c.resultadoAtual.numeroCondutoresParalelosCalculado > 1
                        ? ` × ${c.resultadoAtual.numeroCondutoresParalelosCalculado}`
                        : ''
                    }`
                  : 'inviável'}
              </span>
            )}
          </Link>
        ))}
      </div>
    </div>
  );
}
