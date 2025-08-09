import boto3
import ffmpeg
import os

def lambda_handler(event, context):
    s3 = boto3.client('s3', endpoint_url=os.environ.get('AWS_ENDPOINT_URL', None))
    bucket = os.environ['BUCKET_NAME']
    input_key = 'test_input.mp4'
    output_key = 'test_output.mp4'
    tmp_input = '/tmp/' + input_key
    tmp_output = '/tmp/' + output_key

    # Descargar el archivo de entrada
    s3.download_file(bucket, input_key, tmp_input)

    # Insertar metadatos XMP usando ffmpeg
    ffmpeg.input(tmp_input).output(
        tmp_output,
        **{'metadata': 'Campo1=Valor1', 'metadata': 'Campo2=Valor2'}
    ).run(overwrite_output=True)

    # Subir el archivo de salida
    s3.upload_file(tmp_output, bucket, output_key)

    return {
        'statusCode': 200,
        'body': f'Archivo {output_key} generado con metadatos XMP'
    }