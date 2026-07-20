import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api/client';
import type { Projeto } from '@shared/index';

export function ProjetosPage() {
  const queryClient = useQueryClient();
  const [nome, setNome] = useState('');
  const [descricao, setDescricao] = useState('');
  const [erro, setErro] = useState<string | null>(null);

  const { data: projetos, isLoading } = useQuery({
    queryKey: ['projetos'],
    queryFn: async () => (await api.get<Projeto[]>('/projetos')).data,
  });

  const criar = useMutation({
    mutationFn: async () => (await api.post<Projeto>('/projetos', { nome, descricao: descricao || undefined })).data,
    onSuccess: () => {
      setNome('');
      setDescricao('');
      setErro(null);
      queryClient.invalidateQueries({ queryKey: ['projetos'] });
    },
    onError: (err: any) => setErro(err?.response?.data?.message ?? 'Erro ao criar projeto'),
  });

  return (
    <div>
      <h1>Projetos</h1>

      <div className="card">
        <h2>Novo projeto</h2>
        <div className="field">
          <label>Nome</label>
          <input value={nome} onChange={(e) => setNome(e.target.value)} />
        </div>
        <div className="field">
          <label>Descrição</label>
          <input value={descricao} onChange={(e) => setDescricao(e.target.value)} />
        </div>
        {erro && <div className="error-msg">{erro}</div>}
        <button disabled={!nome || criar.isPending} onClick={() => criar.mutate()}>
          Criar projeto
        </button>
      </div>

      <div className="card">
        <h2>Seus projetos</h2>
        {isLoading && <p>Carregando...</p>}
        {projetos?.length === 0 && <p>Nenhum projeto ainda.</p>}
        {projetos?.map((p) => (
          <Link key={p.id} className="list-item" to={`/projetos/${p.id}`}>
            {p.nome}
            {p.descricao ? ` — ${p.descricao}` : ''}
          </Link>
        ))}
      </div>
    </div>
  );
}
