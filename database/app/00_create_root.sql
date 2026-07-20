-- Superusuário "root" para acesso administrativo direto ao banco (psql,
-- DBeaver, etc.), separado do usuário de conexão da aplicação (calc_cabos).
-- Credenciais de desenvolvimento — trocar antes de qualquer uso fora do
-- ambiente local (ver docker-compose.yml).
CREATE ROLE root WITH LOGIN SUPERUSER PASSWORD 'root';
