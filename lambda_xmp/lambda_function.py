import boto3
import os
from libxmp import XMPFiles, XMPMeta

def lambda_handler(event, context):
    s3 = boto3.client('s3', endpoint_url=os.environ.get('AWS_ENDPOINT_URL', None))
    bucket = os.environ['BUCKET_NAME']
    input_key = 'test_input.mp4'
    output_key = 'test_output.mp4'
    tmp_input = '/tmp/' + input_key
    tmp_output = '/tmp/' + output_key

    # Descargar el archivo de entrada
    s3.download_file(bucket, input_key, tmp_input)

    # Crear metadatos XMP
    xmp = XMPMeta()
    xmp.set_property('http://ns.smartsolutionslab360.com/xmp/', 'Campo1', 'Valor1')
    xmp.set_property('http://ns.smartsolutionslab360.com/xmp/', 'Campo2', 'Valor2')

    # Insertar XMP en el archivo MP4
    xmpfile = XMPFiles(file_path=tmp_input, open_for_update=True)
    xmpfile.put_xmp(xmp)
    xmpfile.close_file()

    # Guardar el archivo modificado como salida
    os.rename(tmp_input, tmp_output)

    # Subir el archivo de salida
    s3.upload_file(tmp_output, bucket, output_key)

    return {
        'statusCode': 200,
        'body': f'Archivo {output_key} generado con metadatos XMP'
    }