export const IMPORT_CIRCUITOS_QUEUE = 'import-circuitos';

export interface ImportCircuitosJobData {
  importJobId: number;
  projetoId: number;
  // Buffer não é serializável em JSON puro (payload do BullMQ/Redis) — o
  // arquivo trafega como base64 e é decodificado de volta no processor.
  arquivoBase64: string;
}
