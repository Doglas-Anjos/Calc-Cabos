import { Route, Routes } from 'react-router-dom';
import { CircuitoFormPage } from './pages/CircuitoFormPage';
import { ImportJobPage } from './pages/ImportJobPage';
import { ProjetoDetailPage } from './pages/ProjetoDetailPage';
import { ProjetosPage } from './pages/ProjetosPage';

export function App() {
  return (
    <div className="app">
      <header className="app-header">
        <a href="/">Calc-Cabos</a>
      </header>
      <main className="app-main">
        <Routes>
          <Route path="/" element={<ProjetosPage />} />
          <Route path="/projetos/:projetoId" element={<ProjetoDetailPage />} />
          <Route path="/projetos/:projetoId/circuitos/novo" element={<CircuitoFormPage />} />
          <Route path="/circuitos/:circuitoId" element={<CircuitoFormPage />} />
          <Route path="/import-jobs/:jobId" element={<ImportJobPage />} />
        </Routes>
      </main>
    </div>
  );
}
