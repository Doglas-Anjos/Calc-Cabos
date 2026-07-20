import { useQuery } from '@tanstack/react-query';
import { Link, useParams } from 'react-router-dom';
import { api } from '../api/client';
import type { ImportJob } from '@shared/index';

export function ImportJobPage() {
  const { jobId } = useParams();

  const { data: job } = useQuery({
    queryKey: ['import-jobs', jobId],
    queryFn: async () => (await api.get<ImportJob>(`/import-jobs/${jobId}`)).data,
    refetchInterval: (query) =>
      query.state.data && ['done', 'failed'].includes(query.state.data.status) ? false : 1500,
  });

  return (
    <div>
      <h1>Importação #{jobId}</h1>
      {!job && <p>Carregando...</p>}
      {job && (
        <div className="card">
          <p>
            Arquivo: <strong>{job.arquivoNome}</strong>
          </p>
          <p>
            Status: <span className={`badge ${job.status === 'done' ? 'ok' : job.status === 'failed' ? 'fail' : ''}`}>{job.status}</span>
          </p>
          <p>
            {job.linhasProcessadas} / {job.totalLinhas || '?'} linhas processadas — {job.linhasErro} com erro
          </p>
          {job.status === 'done' && (
            <p>
              <Link to={`/projetos/${job.projetoId}`}>Ver circuitos do projeto</Link>
            </p>
          )}
        </div>
      )}
    </div>
  );
}
