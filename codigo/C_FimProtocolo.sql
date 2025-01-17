USE [NaturalLife]
GO
/****** Object:  StoredProcedure [dbo].[FimProtocolos]    Script Date: 16/07/2019 08:38:38 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		NaturalLife
-- Create date: 03-07-2019
-- Description:	Alerta pontos de recolha
-- =============================================
ALTER PROCEDURE [dbo].[FimProtocolos]
AS
BEGIN
	
	--params 1º alerta: 90 dias, 2º alerta: 30 dias, 3º alerta: 15 dias
	DECLARE @Alerta1 AS INT = 90 -- 1º Alerta
	DECLARE @Alerta2 AS INT = 30 -- 2º Alerta
	--DECLARE @Alerta3 AS INT = 0 -- 3º Alerta


	IF EXISTS(SELECT
				pontos_recolha.id,
				pontos_recolha.nome,
				pontos_recolha.fimProtocolo,
				DATEDIFF(day, GETDATE(), pontos_recolha.fimProtocolo)
			FROM pontos_recolha
			WHERE   
				DATEDIFF(day, GETDATE(), pontos_recolha.fimProtocolo) in (@Alerta1, @Alerta2))
	BEGIN

		--Declara as variaveis
		Declare @HTMLBody nvarchar(max),
				@tableBody nvarchar(max)
	
		--Cria a tabela HTML
		SET @tableBody = CONVERT(NVARCHAR(MAX), (SELECT
			(SELECT '' FOR XML PATH(''), TYPE) AS 'caption',
			(SELECT 
				'ID' AS th,
				'Nome' AS th,
				'Fim do protocolo' AS th,
				'Dias Restantes' AS th 
				FOR XML RAW('tr'), ELEMENTS, TYPE) AS 'thead',
			(

			--Inicio da Query
			SELECT
				pontos_recolha.id as td,
				pontos_recolha.nome as td,
				pontos_recolha.fimProtocolo as td,
				DATEDIFF(day, GETDATE(), pontos_recolha.fimProtocolo) as td
			FROM pontos_recolha
			WHERE   
				DATEDIFF(day, GETDATE(), pontos_recolha.fimProtocolo) in (@Alerta1, @Alerta2)
			ORDER BY DATEDIFF(day, GETDATE(), pontos_recolha.fimProtocolo) ASC
			--Fim da Query
    
			FOR XML RAW('tr'), ELEMENTS, TYPE
			) AS 'tbody'
		FOR XML PATH(''), ROOT('table')));


		--Corpo do HTML
		SET @HTMLBody = '<html><head><style>
			table, th, td {
				border: 1px solid black;
			}
			table {
				width: 100%;
				border-collapse: collapse;
			}
			th {
				width: 25%;
				background-color: #99CCFF;
			}
			tr {
				width: 25%;
				background-color: #F1F1F1;
			}
		</style><title>Registo de Produção maior que Registo de Recolha</title></head><body>'
		--SET @HTMLBody = @HTMLBody + 'Aproxima-se a data do fim de protocolo com os seguintes Pontos de Recolha<br/>'
		SET @HTMLBody = @HTMLBody + @tableBody + '</body></html>'

		--envia o email
		exec msdb.dbo.sp_send_dbmail 
		@profile_name = 'NaturalLife', 
		@recipients = '<Email de Destinatário>',
		@subject = '[ALERTA] Fim de Protocolo', 
		@body = @HTMLBody, 
		@body_format = 'HTML'

	END

END
